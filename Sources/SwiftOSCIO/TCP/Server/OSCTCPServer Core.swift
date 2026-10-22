//
//  OSCTCPServer Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

internal import SwiftOSCIOInternals
import Foundation
import NIO
import SwiftOSCCore

extension OSCTCPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPServer

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.Core.syncQueue", target: .global())

        let queue: DispatchQueue
        private let queueKey = DispatchSpecificKey<Void>()

        // anywhere that we are assigning this variable, it is wrapped in sync calls to `queue`
        // so we don't need to wrap it with `syncQueue` to synchronize
        nonisolated(unsafe) private var ipv4Channel: (any Channel)?
        
        // anywhere that we are assigning this variable, it is wrapped in sync calls to `queue`
        // so we don't need to wrap it with `syncQueue` to synchronize
        nonisolated(unsafe) private var ipv6Channel: (any Channel)?

        /// Currently connected client sessions.
        private var _clients: [OSCTCPClientSessionID: ClientConnection] {
            get {
                syncQueue.sync { __clients }
            }
            _modify {
                var value = syncQueue.sync { __clients }
                yield &value
                syncQueue.sync { __clients = value }
            }
            set {
                syncQueue.sync { __clients = newValue }
            }
        }

        nonisolated(unsafe) private var __clients: [OSCTCPClientSessionID: ClientConnection] = [:]

        var receiveHandler: OSCPacketHandler? {
            get { syncQueue.sync { _receiveHandler } }
            set { syncQueue.sync { _receiveHandler = newValue } }
        }

        nonisolated(unsafe) private var _receiveHandler: OSCPacketHandler?

        var receiveErrorHandler: OSCDecodeErrorHandlerBlock? {
            get { syncQueue.sync { _receiveErrorHandler } }
            set { syncQueue.sync { _receiveErrorHandler = newValue } }
        }

        nonisolated(unsafe) private var _receiveErrorHandler: OSCDecodeErrorHandlerBlock?

        var notificationHandler: Parent.NotificationHandlerBlock? {
            get { syncQueue.sync { _notificationHandler } }
            set { syncQueue.sync { _notificationHandler = newValue } }
        }

        nonisolated(unsafe) private var _notificationHandler: Parent.NotificationHandlerBlock?

        var localHost: String? {
            isStarted
                ? (ipv4Channel?.localAddress?.ipAddress ?? ipv6Channel?.localAddress?.ipAddress)
                : nil
        }

        var localPort: UInt16 {
            if let port = localPortIPv4 ?? localPortIPv6 {
                return UInt16(port)
            }
            return preferredLocalPort ?? 0
        }
        
        var localPortIPv4: UInt16? {
            if let port = ipv4Channel?.localAddress?.port { UInt16(port) } else { nil }
        }
        
        var localPortIPv6: UInt16? {
            if let port = ipv6Channel?.localAddress?.port { UInt16(port) } else { nil }
        }

        private var preferredLocalPort: UInt16? {
            get { syncQueue.sync { _preferredLocalPort } }
            set { syncQueue.sync { _preferredLocalPort = newValue } }
        }

        nonisolated(unsafe) private var _preferredLocalPort: UInt16?

        let interface: String?

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the TCP server is stopped and restarted again.")
                }
            }
        }

        nonisolated(unsafe) private var _isIPv6Enabled: Bool

        var isStarted: Bool {
            isIPv4Started || isIPv6Started
        }
        
        private var isIPv4Started: Bool {
            ipv4Channel != nil
        }
        
        private var isIPv6Started: Bool {
            ipv6Channel != nil
        }

        let framingMode: OSCTCPFramingMode

        init(
            port: UInt16?,
            interface: String?,
            isIPv6Enabled: Bool,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _preferredLocalPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            _isIPv6Enabled = isIPv6Enabled
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(
                label: "com.orchetect.SwiftOSC.OSCTCPServer.queue",
                target: .global() // do NOT use syncQueue
            )
            queue.setSpecific(key: queueKey, value: ())
            self.queue = queue

            _receiveHandler = receiveHandler
        }

        deinit {
            stop()
        }
    }
}

extension OSCTCPServer.Core: Sendable { }

// MARK: - Lifecycle

extension OSCTCPServer.Core {
    func start() throws {
        try syncOnQueue {
            try _start()
        }
    }
    
    func _start() throws {
        #if canImport(Darwin)
        // NIO on Apple platforms support dual TCP "server" channels binding to both IPv4 or IPv6
        try _startIPv4()
        if isIPv6Enabled { try _startIPv6() }
        #else
        // TODO: NIO on Linux (and possibly Android) does not support dual TCP "server" channels
        // however when binding to IPv6 a "sever" channel will also accept IPv4 connections using IPv6 address translation.
        // the compromise is that IPv4 clients will be seen as having IPv6 addresses
        // (ie: local loopback client connecting to 127.0.0.1 (IPv4)
        // will be seen as "::ffff:127.0.0.1" (IPv6) which is not the same as "::1")
        // See: https://stackoverflow.com/questions/49793630/is-ffff127-0-0-1-localhost
        if isIPv6Enabled { try _startIPv6() } else { try _startIPv4() }
        #endif
    }
    
    private func _startIPv4() throws {
        guard !isIPv4Started else { return }
        if let channel = try _start(isIPv4: true) { ipv4Channel = channel }
    }
    
    private func _startIPv6() throws {
        guard !isIPv6Started else { return }
        if let channel = try _start(isIPv4: false) { ipv6Channel = channel }
    }
    
    private func _start(isIPv4: Bool) throws -> (any Channel)? {
        if isIPv4 { _stopIPv4() } else { _stopIPv6() }
        
        // bind to interface, if specified
        // `nil` return value is not an error condition; just means this channel is not used
        guard let host = try hostAddressStringForBinding(interface: interface, isIPv4: isIPv4) else { return nil }
        
        // use previous port, otherwise assign random port
        let port = if let inUsePort = localPortIPv4 ?? localPortIPv6 {
            Int(inUsePort)
        } else if let preferredLocalPort {
            Int(preferredLocalPort)
        } else {
            // the port will be randomly assigned by the system
            0
        }
        
        // channel setup
        
        // Linux (and possibly Android) requires port reuse to be enabled in order to allow local loopback connections
        let reuseValue: ChannelOptions.Types.SocketOption.Value = 1
        
        let bootstrap = ServerBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: reuseValue)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    switch self.framingMode {
                    case .osc1_0:
                        try channel.pipeline
                            .syncOperations
                            .addHandler(ByteToMessageHandler(OSCTCPLengthHeaderFrameDecoder()))
                    case .osc1_1:
                        try channel.pipeline
                            .syncOperations
                            .addHandler(ByteToMessageHandler(OSCTCPSLIPFrameDecoder()))
                    }
                    try channel.pipeline
                        .syncOperations
                        .addHandler(ChildChannelHandler(server: self))
                }
            }
            .childChannelOption(.socketOption(.so_reuseaddr), value: reuseValue)
        
        // #if DEBUG
        // print(
        //     "\(type(of: Parent.self)) \(#function) Binding \(isIPv4 ? "IPv4" : "IPv6") to: \(host):\(port). "
        //         + "Interface was \(interface ?? "<nil>")."
        // )
        // #endif
        
        let configuredChannel = bootstrap
            .bind(host: host, port: port)
        
        let waitingChannel = try configuredChannel
            .wait()
        
        return waitingChannel
    }

    func stop() {
        syncOnQueue {
            _stopIPv4()
            _stopIPv6()
        }
    }
    
    private func _stopIPv4() {
        try? ipv4Channel?.close().wait()
        ipv4Channel = nil
    }
    
    private func _stopIPv6() {
        try? ipv6Channel?.close().wait()
        ipv6Channel = nil
    }
}

// MARK: - Queue Utilities

extension OSCTCPServer.Core {
    private func syncOnQueue<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            try operation()
        } else {
            try queue.sync(execute: operation)
        }
    }
}

// MARK: - Communication

extension OSCTCPServer.Core {
    func send(
        _ packet: OSCPacket,
        toClientIDs clientIDs: [OSCTCPClientSessionID]?,
        errorHandler: ((_ clientID: OSCTCPClientSessionID, _ error: any Error) -> Void)?
    ) {
        let clientIDs = clientIDs ?? Array(_clients.keys)
        for clientID in clientIDs {
            do {
                try send(packet, toClientID: clientID)
            } catch {
                errorHandler?(clientID, error)
            }
        }
    }

    func send(_ oscPacket: OSCPacket, toClientID clientID: OSCTCPClientSessionID) throws {
        guard let connection = _clients[clientID] else {
            throw OSCIOError.clientNotFound(clientID: clientID)
        }

        try connection.send(oscPacket)
    }
}

extension OSCTCPServer.Core: _OSCTCPPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPServer.Core: OSCTCPGeneratesServerNotificationsProtocol {
    func generateConnectedNotification(remoteHost: String, remotePort: UInt16, clientID: OSCTCPClientSessionID) {
        let notif: Parent.Notification = .connected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID)
        notificationHandler?(notif)
    }

    func generateDisconnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID,
        error: (any Error)?
    ) {
        let notif: Parent.Notification = .disconnected(remoteHost: remoteHost, remotePort: remotePort, clientID: clientID, error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPServer.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }

    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        notificationHandler = handler
    }

    var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        _clients
            .reduce(into: [:] as [OSCTCPClientSessionID: (host: String, port: UInt16)]) { base, element in
                base[element.key] = (
                    host: element.value.remoteHost,
                    port: element.value.remotePort
                )
            }
    }

    func disconnectClient(clientID: OSCTCPClientSessionID) {
        closeClient(clientID: clientID)
    }
}

// MARK: - Clients

extension OSCTCPServer.Core {
    /// Close connections for any connected clients and remove them from the list of connected clients.
    func closeClients() {
        let clientIDs = _clients.keys // take local copy before mutating collection
        for clientID in clientIDs {
            closeClient(clientID: clientID)
        }
    }

    func addClient(channel: any Channel) -> OSCTCPClientSessionID {
        let clientID = newClientID()
        let connection = ClientConnection(
            server: self,
            channel: channel,
            clientID: clientID,
            framingMode: framingMode
        )
        _clients[clientID] = connection

        return clientID
    }

    /// Generate a new client ID that is not currently in use by any connected client(s).
    private func newClientID() -> OSCTCPClientSessionID {
        syncOnQueue {
            var clientID = 0
            while clientID == 0 || _clients.keys.contains(clientID) {
                // don't allow 0 or negative numbers
                clientID = Int.random(in: 1 ... Int.max)
            }

            assert(clientID > 0)
            return clientID
        }
    }

    /// Close a connection and remove it from the list of connected clients.
    func closeClient(clientID: Int) {
        syncOnQueue {
            _clients[clientID]?.close()
            _clients[clientID] = nil
        }
    }
}

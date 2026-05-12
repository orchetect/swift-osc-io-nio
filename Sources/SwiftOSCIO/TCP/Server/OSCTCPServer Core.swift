//
//  OSCTCPServer Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore
internal import SwiftOSCIOInternals

extension OSCTCPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPServer
        
        var channel: (any Channel)?
        private var _clients: [OSCTCPClientSessionID: ClientConnection] = [:]
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        var notificationHandler: NotificationHandlerBlock?
        
        var timeTagMode: OSCTimeTagMode
        
        var localPort: UInt16 {
            UInt16(channel?.localAddress?.port ?? 0)
        }
        private var _localPort: UInt16?
        
        let interface: String?
        
        var isStarted: Bool {
            channel?.isActive ?? false
        }
        
        let framingMode: OSCTCPFramingMode
        
        init(
            port: UInt16?,
            interface: String?,
            timeTagMode: OSCTimeTagMode,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPServer.queue")
            self.queue = queue
            self.receiveHandler = receiveHandler
        }
        
        deinit {
            stop()
        }
    }
}

extension OSCTCPServer.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer.Core {
    func start() throws {
        guard !isStarted else { return }
        
        var bootstrap = ServerBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .serverChannelOption(.socketOption(.so_reuseaddr), value: 1)
            .childChannelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    switch self.framingMode {
                    case .osc1_0:
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(OSCTCPLengthHeaderFrameDecoder()))
                    case .osc1_1:
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(OSCTCPSLIPFrameDecoder()))
                    }
                    try channel.pipeline.syncOperations.addHandler(ChildChannelHandler(server: self))
                }
            }
        
        // bind to interface, if specified
        let host: String
        if let interface {
            guard let interface = try networkDevices(matchingNameOrAddress: interface, protocols: [.inet]).first,
                  let address = interface.address.ipAddress
            else {
                throw OSCIOError.invalidInterface
            }
            host = address
        } else {
            host = "0.0.0.0"
        }
        
        let port = Int(_localPort ?? localPort)
        
        channel = try bootstrap
            .bind(host: host, port: port)
            .wait()
    }
    
    func stop() {
        // disconnect all clients
        closeClients()
        
        // close server
        channel?.close(promise: nil)
        channel = nil
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

extension OSCTCPServer.Core: _OSCTCPHandlerProtocol {
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
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }

    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        queue.async {
            self.notificationHandler = handler
        }
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
        for clientID in _clients.keys {
            closeClient(clientID: clientID)
        }
    }
    
    func addClient(channel: any Channel) -> OSCTCPClientSessionID {
        let clientID = newClientID()
        let connection = ClientConnection(server: self, channel: channel, clientID: clientID, framingMode: framingMode)
        _clients[clientID] = connection
        
        return clientID
    }
    
    /// Generate a new client ID that is not currently in use by any connected client(s).
    private func newClientID() -> OSCTCPClientSessionID {
        var clientID = 0
        while clientID == 0 || _clients.keys.contains(clientID) {
            // don't allow 0 or negative numbers
            clientID = Int.random(in: 1 ... Int.max)
        }
        assert(clientID > 0)
        return clientID
    }
    
    /// Close a connection and remove it from the list of connected clients.
    func closeClient(clientID: Int) {
        _clients[clientID]?.close()
        _clients[clientID] = nil
    }
}

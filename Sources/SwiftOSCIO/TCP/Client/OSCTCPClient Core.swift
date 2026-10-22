//
//  OSCTCPClient Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

internal import SwiftOSCIOInternals
import Foundation
import NIO
import SwiftOSCIOCore

extension OSCTCPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPClient

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPClient.Core.syncQueue", target: .global())

        let queue: DispatchQueue
        private let queueKey = DispatchSpecificKey<Void>()

        // anywhere that we are assigning this variable, it is wrapped in sync calls to `queue`
        // so we don't need to wrap it with `syncQueue` to synchronize
        nonisolated(unsafe) var channel: (any Channel)?

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
            isConnected ? channel?.localAddress?.ipAddress : nil
        }

        var localPort: UInt16? {
            if let port = channel?.localAddress?.port { UInt16(port) } else { nil }
        }

        let remoteHost: String

        let remotePort: UInt16

        let interface: String?

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isConnected {
                    print("Setting isIPv6Enabled will not have any effect until the TCP client is disconnected and reconnected again.")
                }
            }
        }

        nonisolated(unsafe) private var _isIPv6Enabled: Bool

        var isIPv6AddressTranslationToIPv4Enabled: Bool {
            get { syncQueue.sync { _isIPv6AddressTranslationToIPv4Enabled } }
            set { syncQueue.sync { _isIPv6AddressTranslationToIPv4Enabled = newValue } }
        }

        nonisolated(unsafe) private var _isIPv6AddressTranslationToIPv4Enabled: Bool = false

        var isConnected: Bool {
            channel?.isActive ?? false
        }

        let framingMode: OSCTCPFramingMode

        init(
            remoteHost: String,
            remotePort: UInt16,
            interface: String?,
            isIPv6Enabled: Bool,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            self.remoteHost = remoteHost
            self.remotePort = remotePort
            self.interface = interface
            _isIPv6Enabled = isIPv6Enabled
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(
                label: "com.orchetect.SwiftOSC.OSCTCPClient.queue",
                target: .global() // do NOT use syncQueue
            )
            self.queue = queue
            queue.setSpecific(key: queueKey, value: ())
            _receiveHandler = receiveHandler
        }

        deinit {
            close()
        }
    }
}

extension OSCTCPClient.Core: Sendable { }

// MARK: - Lifecycle

extension OSCTCPClient.Core {
    func connect(timeout: TimeInterval) throws {
        try syncOnQueue {
            // sanitize inputs
            // negative values mean indefinite (no timeout) which is a bit dangerous
            let timeout = Int64(max(1.0, timeout))

            let handler = ChannelHandler(oscServer: self)

            // channel setup
            
            // Linux (and possibly Android) requires port reuse to be enabled in order to allow local loopback connections
            let reuseValue: ChannelOptions.Types.SocketOption.Value = 1
            
            var bootstrap = ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
                .channelOption(.socketOption(.so_reuseaddr), value: reuseValue)
                .connectTimeout(.seconds(timeout))
                .channelInitializer { channel in
                    channel.eventLoop.makeCompletedFuture {
                        // chose which decoder to use
                        switch self.framingMode {
                        case .osc1_0: // Length Header
                            try channel.pipeline
                                .syncOperations
                                .addHandler(ByteToMessageHandler(OSCTCPLengthHeaderFrameDecoder()))
                        case .osc1_1: // SLIP
                            try channel.pipeline
                                .syncOperations
                                .addHandler(ByteToMessageHandler(OSCTCPSLIPFrameDecoder()))
                        }
                        // add client handler
                        try channel.pipeline.syncOperations.addHandler(handler)
                    }
                }

            // bind to interface, if specified
            if let interface {
                let interfaceAddress = switch interface {
                case "0.0.0.0",
                     "::" where isIPv6Enabled:
                    // pass thru wildcard
                    try SocketAddress.makeAddressResolvingHost(interface, port: 0)
                default:
                    try resolveSocketAddress(ofNetworkDeviceNameOrAddress: interface, forRemoteHost: remoteHost)
                }

                bootstrap = bootstrap
                    .bind(to: interfaceAddress)
            }

            let resolvedAddress: SocketAddress
            if !isIPv6Enabled, isIPv6AddressTranslationToIPv4Enabled {
                // translate an IPv6 host/IP to an IPv4 if possible.
                let proposedRemoteHost = try IPUtils.ipAddressUsingReverseLookup(forHostnameOrIPAddress: remoteHost, family: .ipv4)
                guard let proposedRemoteHost else {
                    throw OSCIOError.noRemoteHost // TODO: could use a new invalidRemoteHost case
                }
                resolvedAddress = try SocketAddress(ipAddress: proposedRemoteHost, port: Int(remotePort))
            } else {
                resolvedAddress = try resolveSocketAddressPreferringIPv4(
                    forHostnameOrIPAddress: remoteHost,
                    port: remotePort,
                    isIPv6Enabled: isIPv6Enabled
                )
            }

            // #if DEBUG
            // print(
            //     "\(type(of: Parent.self)) \(#function) "
            //         + "Connecting to: \(resolvedAddress.ipAddress ?? "<nil-address>"):\(resolvedAddress.port?.description ?? "<nil-port>"). "
            //         + "Interface was \(interface ?? "<nil>")"
            // )
            // #endif
            
            // connect to host
            let configuredChannel = try bootstrap
                .connect(to: resolvedAddress)
                .wait()

            channel = configuredChannel
        }
    }

    func close() {
        syncOnQueue {
            // close the connection
            channel?.close(promise: nil)
            // deallocate channel
            channel = nil
        }
    }
}

// MARK: - Queue Utilities

extension OSCTCPClient.Core {
    private func syncOnQueue<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            try operation()
        } else {
            try queue.sync(execute: operation)
        }
    }
}

// MARK: - Communication

extension OSCTCPClient.Core: _OSCTCPPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCTCPClient.Core: _OSCTCPSendProtocol {
    // provides implementation for sending OSC data

    func send(_ oscPacket: OSCPacket) throws {
        try _send(oscPacket)
    }
}

extension OSCTCPClient.Core: OSCTCPGeneratesClientNotificationsProtocol {
    func generateConnectedNotification() {
        let notif: Parent.Notification = .connected
        notificationHandler?(notif)
    }

    func generateDisconnectedNotification(error: (any Error)?) {
        let notif: Parent.Notification = .disconnected(error: error)
        notificationHandler?(notif)
    }
}

// MARK: - Properties

extension OSCTCPClient.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }

    func setNotificationHandler(_ handler: Parent.NotificationHandlerBlock?) {
        notificationHandler = handler
    }
}

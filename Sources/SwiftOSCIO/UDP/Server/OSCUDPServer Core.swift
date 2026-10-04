//
//  OSCUDPServer Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore

extension OSCUDPServer {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPServer

        /// Internal queue used for synchronizing access to mutable properties.
        let syncQueue = DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.Core.syncQueue", target: .global())

        let queue: DispatchQueue
        private let queueKey = DispatchSpecificKey<Void>()

        // anywhere that we are assigning this variable, it is wrapped in sync calls to `queue`
        // so we don't need to wrap it with `syncQueue` to synchronize
        nonisolated(unsafe) private var ipv4Channel: (any Channel)?

        // anywhere that we are assigning this variable, it is wrapped in sync calls to `queue`
        // so we don't need to wrap it with `syncQueue` to synchronize
        nonisolated(unsafe) private var ipv6Channel: (any Channel)?

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

        var isPortReuseEnabled: Bool {
            get { syncQueue.sync { _isPortReuseEnabled } }
            set { syncQueue.sync { _isPortReuseEnabled = newValue } }
        }

        nonisolated(unsafe) private var _isPortReuseEnabled: Bool

        var isIPv6Enabled: Bool {
            get {
                syncQueue.sync { _isIPv6Enabled }
            }
            set {
                syncQueue.sync { _isIPv6Enabled = newValue }
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP server is stopped and started again.")
                }
            }
        }

        nonisolated(unsafe) private var _isIPv6Enabled: Bool

        var isStarted: Bool {
            isIPv4Started || isIPv6Started
        }

        private var isIPv4Started: Bool {
            ipv4Channel?.isActive ?? false
        }

        private var isIPv6Started: Bool {
            ipv6Channel?.isActive ?? false
        }

        init(
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv6Enabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _preferredLocalPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            _isPortReuseEnabled = isPortReuseEnabled
            _isIPv6Enabled = isIPv6Enabled
            let queue = queue ?? DispatchQueue(
                label: "com.orchetect.SwiftOSC.OSCUDPServer.queue",
                target: .global() // do NOT use syncQueue
            )
            self.queue = queue
            queue.setSpecific(key: queueKey, value: ())
            _receiveHandler = receiveHandler
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPServer.Core: Sendable { }

// MARK: - Lifecycle

extension OSCUDPServer.Core {
    private func syncOnQueue<T>(_ operation: () throws -> T) rethrows -> T {
        if DispatchQueue.getSpecific(key: queueKey) != nil {
            return try operation()
        }

        return try queue.sync(execute: operation)
    }
    
    func start() throws {
        try queue.sync {
            try _start()
        }
    }

    func _start() throws {
        try _startIPv4()
        if isIPv6Enabled { try _startIPv6() }
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
        
        #if canImport(Darwin)
        let reuseValue: ChannelOptions.Types.SocketOption.Value = isPortReuseEnabled ? 1 : 0
        #else
        // Linux (and possibly Android) requires port reuse to be enabled in order to allow local loopback connections
        let reuseValue: ChannelOptions.Types.SocketOption.Value = 1
        #endif
        
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: reuseValue)
            .channelInitializer { channel in
                channel.pipeline.addHandler(OSCUDPChannelHandler(oscServer: self))
            }

        let configuredChannel = bootstrap
            .bind(host: host, port: port)

        return try configuredChannel
            .wait()
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

// MARK: - Communication

extension OSCUDPServer.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        receiveHandler = handler
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        receiveErrorHandler = handler
    }
}

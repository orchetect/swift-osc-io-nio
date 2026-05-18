//
//  OSCUDPClient Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore

extension OSCUDPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPClient

        let queue: DispatchQueue

        private var channel: (any Channel)?

        var localPort: UInt16 {
            if let port = channel?.localAddress?.port {
                UInt16(port)
            } else {
                _localPort ?? 0
            }
        }

        private var _localPort: UInt16?

        private(set) var interface: String?

        var isPortReuseEnabled: Bool = false

        var isIPv4BroadcastEnabled: Bool {
            get { _isIPv4BroadcastEnabled }
            set {
                _isIPv4BroadcastEnabled = newValue
                let broadcast: ChannelOptions.Types.SocketOption.Value = newValue ? 1 : 0

                channel?
                    .setOption(.socketOption(.so_broadcast), value: broadcast)
                    .whenComplete { error in }
            }
        }
        private var _isIPv4BroadcastEnabled: Bool = false

        var isIPv6Enabled: Bool = false

        var isStarted: Bool {
            channel?.isActive ?? false
        }
        
        init(
            localPort: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv4BroadcastEnabled: Bool,
            queue: DispatchQueue?
        ) {
            self.queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPClient.queue", target: .global())
            _localPort = (localPort == nil || localPort == 0) ? nil : localPort
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            self.isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPClient.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCUDPClient.Core {
    func start() throws {
        try queue.sync {
            try _start()
        }
    }
    
    private func _start(remoteHost: String? = nil, force: Bool = false) throws {
        if !force { guard !isStarted else { return } }
        
        _stop()
        
        let reuseAddress: ChannelOptions.Types.SocketOption.Value = isPortReuseEnabled ? 1 : 0
        let broadcast: ChannelOptions.Types.SocketOption.Value = _isIPv4BroadcastEnabled ? 1 : 0
        
        // bind to interface, if specified
        let host: String = if let interface {
            switch interface {
            case "0.0.0.0", "::":
                interface // pass thru wildcard
            default:
                try resolveSocketAddressString(ofNetworkDeviceNameOrAddress: interface, isIPv6Enabled: isIPv6Enabled)
            }
        } else {
            // Don't bind to "localhost", "127.0.0.1" (IPv4) or "::1" (IPv6)
            if let remoteHost, isIPv6Enabled {
                switch try SocketAddress.makeAddressResolvingHost(remoteHost, port: 1).protocol { // port number doesn't matter here
                case .inet: "0.0.0.0"
                case .inet6: "::"
                default: isIPv6Enabled ? "::" : "0.0.0.0"
                }
            } else {
                isIPv6Enabled ? "::" : "0.0.0.0"
            }
        }
        
        let port = Int(_localPort ?? 0)
        
        // Channel Setup
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            // configure port reuse
            .channelOption(.socketOption(.so_reuseaddr), value: reuseAddress)
            // configure ipv4 broadcast
            .channelOption(.socketOption(.so_broadcast), value: broadcast)
        
        let configuredChannel = try bootstrap
            // bind to host and port
            .bind(host: host, port: port)
        
        channel = try configuredChannel
            .wait()
    }

    func stop() {
        queue.sync {
            _stop()
        }
    }
    
    private func _stop() {
        // close channel -> opportunity for completion handler
        channel?.close(promise: nil)
        channel = nil
    }
}

// MARK: - Communication

extension OSCUDPClient.Core {
    func send(_ packet: OSCPacket, to host: String, port: UInt16) throws {
        try queue.sync {
            if !isStarted {
                try _start(remoteHost: host, force: true)
            }

            guard let channel else {
                throw OSCIOError.notStarted
            }

            // resolve host and port to `SocketAddress`
            // TODO: NIO forces resolving a hostname to its IPv6 address if one is available, but we want to get its IPv4 address if `isIPv6Enabled` is not true
            let remoteAddress = try SocketAddress.makeAddressResolvingHost(host, port: Int(port))

            // create buffer from data
            let data = try packet.rawData()
            let buffer: ByteBuffer = channel.allocator.buffer(bytes: data)

            let envelope = AddressedEnvelope(remoteAddress: remoteAddress, data: buffer)
            channel.writeAndFlush(envelope, promise: nil)
        }
    }
}

//
//  OSCUDPClient Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore
internal import SwiftOSCIOInternals

extension OSCUDPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPClient

        let queue: DispatchQueue

        private var ipv4Channel: (any Channel)?
        private var ipv6Channel: (any Channel)?

        var localPort: UInt16 {
            if let port = ipv4Channel?.localAddress?.port ?? ipv6Channel?.localAddress?.port{
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

                ipv4Channel?
                    .setOption(.socketOption(.so_broadcast), value: broadcast)
                    .whenComplete { error in }
            }
        }
        private var _isIPv4BroadcastEnabled: Bool = false

        var isIPv6Enabled: Bool = true {
            didSet {
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP client is stopped and started again.")
                }
            }
        }

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
            isIPv4 ? "0.0.0.0" : "::"
        }
        
        let port = Int(_localPort ?? 0)
        
        // Channel Setup
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            // configure port reuse
            .channelOption(.socketOption(.so_reuseaddr), value: reuseAddress)
            // configure ipv4 broadcast
            .channelOption(.socketOption(.so_broadcast), value: broadcast)
        
        let configuredChannel = bootstrap
            // bind to host and port
            .bind(host: host, port: port)
        
        return try configuredChannel
            .wait()
    }

    func stop() {
        queue.sync {
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

extension OSCUDPClient.Core {
    func send(_ packet: OSCPacket, to host: String, port: UInt16) throws {
        try queue.sync {
            if !isStarted {
                try _start()
            }

            // resolve host and port to `SocketAddress`
            let remoteAddress = try resolveSocketAddress(forHostnameOrIPAddress: host, port: port, isIPv6Enabled: isIPv6Enabled)
            
            // use corresponding channel for IP protocol
            let channel = switch remoteAddress.protocol {
            case .inet: ipv4Channel
            case .inet6: ipv6Channel
            default: throw OSCIOError.noRemoteHost
            }
            
            guard let channel else {
                throw OSCIOError.notStarted
            }
            
            // create buffer from data
            let data = try packet.rawData()
            let buffer: ByteBuffer = channel.allocator.buffer(bytes: data)

            let envelope = AddressedEnvelope(remoteAddress: remoteAddress, data: buffer)
            try channel.writeAndFlush(envelope)
                .wait()
        }
    }
}

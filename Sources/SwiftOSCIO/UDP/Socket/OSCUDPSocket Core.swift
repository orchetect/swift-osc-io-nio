//
//  OSCUDPSocket Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore

extension OSCUDPSocket {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCUDPSocket

        private var ipv4Channel: (any Channel)?
        private var ipv6Channel: (any Channel)?
        let queue: DispatchQueue
        var receiveHandler: OSCPacketHandler?
        var receiveErrorHandler: OSCDecodeErrorHandlerBlock?

        var remoteHost: String? {
            didSet {
                // convert empty string to nil
                if let rh = remoteHost, rh.isEmpty {
                    remoteHost = nil
                }
            }
        }

        var localPort: UInt16 {
            if let port = ipv4Channel?.localAddress?.port ?? ipv6Channel?.localAddress?.port{
                return UInt16(port)
            }
            return _localPort ?? 0
        }

        private var _localPort: UInt16?

        var remotePort: UInt16 {
            get { _remotePort ?? localPort }
            set { _remotePort = (newValue == 0) ? nil : newValue }
        }

        private var _remotePort: UInt16?

        private(set) var interface: String?

        let isIPv4BroadcastEnabled: Bool

        var isIPv6Enabled: Bool = true {
            didSet {
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP socket is stopped and started again.")
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
            remoteHost: String?,
            remotePort: UInt16?,
            interface: String?,
            isIPv4BroadcastEnabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            self.remoteHost = (remoteHost ?? "").isEmpty ? nil : remoteHost // convert empty string to nil
            _localPort = (localPort == nil || localPort == 0) ? nil : localPort
            _remotePort = (remotePort == nil || remotePort == 0) ? nil : remotePort
            self.interface = interface
            self.isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPSocket.queue", target: .global())
            self.queue = queue
            self.receiveHandler = receiveHandler
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPSocket.Core: @unchecked Sendable { }

// MARK: - Lifecycle

extension OSCUDPSocket.Core {
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
        
        let broadcast: ChannelOptions.Types.SocketOption.Value = isIPv4BroadcastEnabled ? 1 : 0
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .channelOption(.socketOption(.so_broadcast), value: broadcast)
            .channelInitializer { channel in
                channel.pipeline.addHandler(OSCUDPChannelHandler(oscServer: self))
            }
        
        // bind to interface, if specified
        let host: String = if let interface {
            switch interface {
            case "0.0.0.0", "::":
                interface // pass thru wildcard
            default:
                if let remoteHost {
                    try resolveSocketAddressString(ofNetworkDeviceNameOrAddress: interface, forRemoteHost: remoteHost)
                } else {
                    try resolveSocketAddressString(ofNetworkDeviceNameOrAddress: interface, isIPv6Enabled: isIPv6Enabled)
                }
            }
        } else {
            // Don't bind to "localhost", "127.0.0.1" (IPv4) or "::1" (IPv6)
            isIPv4 ? "0.0.0.0" : "::"
        }
        
        let port = Int(_localPort ?? localPort)
        
        let configuredChannel = bootstrap
            .bind(host: host, port: port)
        
        let waitingChannel = try configuredChannel
            .wait()
        
        return waitingChannel
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

extension OSCUDPSocket.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCUDPSocket.Core {
    func send(_ packet: OSCPacket, to host: String?, port: UInt16?) throws {
        try queue.sync {
            guard isStarted else {
                throw OSCIOError.notStarted
            }
            
            let port = port ?? remotePort
            
            guard let host = host ?? remoteHost else {
                throw OSCIOError.noRemoteHost
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

// MARK: - Properties

extension OSCUDPSocket.Core {
    func setReceiveHandler(_ handler: OSCPacketHandler?) {
        queue.sync {
            self.receiveHandler = handler
        }
    }

    func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        queue.sync {
            self.receiveErrorHandler = handler
        }
    }
}

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

        private var ipv4Channel: (any Channel)?
        private var ipv6Channel: (any Channel)?
        let queue: DispatchQueue
        var receiveHandler: OSCPacketHandler?
        var receiveErrorHandler: OSCDecodeErrorHandlerBlock?

        var localPort: UInt16 {
            if let port = ipv4Channel?.localAddress?.port ?? ipv6Channel?.localAddress?.port {
                return UInt16(port)
            }
            return _localPort ?? 0
        }

        private var _localPort: UInt16?

        private(set) var interface: String?

        var isPortReuseEnabled: Bool = false

        var isIPv6Enabled: Bool = true {
            didSet {
                if isStarted {
                    print("Setting isIPv6Enabled will not have any effect until the UDP server is stopped and started again.")
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
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCPacketHandler?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.queue", target: .global())
            self.queue = queue
            self.receiveHandler = receiveHandler
        }

        deinit {
            stop()
        }
    }
}

extension OSCUDPServer.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCUDPServer.Core {
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
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: reuseAddress)
            .channelInitializer { channel in
                channel.pipeline.addHandler(OSCUDPChannelHandler(oscServer: self))
            }
        
        // bind to interface, if specified
        let host: String = if let interface {
            switch interface {
            case "0.0.0.0", "::":
                interface // pass thru wildcard
            default:
                try resolveSocketAddressString(ofNetworkDeviceNameOrAddress: interface, isIPv6Enabled: !isIPv4)
            }
        } else {
            // Don't bind to "localhost", "127.0.0.1" (IPv4) or "::1" (IPv6)
            isIPv4 ? "0.0.0.0" : "::"
        }
        
        let port = Int(_localPort ?? localPort)
        
        let configuredChannel = bootstrap
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

extension OSCUDPServer.Core: _OSCPacketDispatcherProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
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

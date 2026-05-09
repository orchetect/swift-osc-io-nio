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
        
        private var channel: (any Channel)? = nil
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        
        var timeTagMode: OSCTimeTagMode
        
        var localPort: UInt16 {
            if let port = channel?.localAddress?.port {
                return UInt16(port)
            }
            return _localPort ?? 0
        }
        private var _localPort: UInt16?
        
        private(set) var interface: String?
        
        var isPortReuseEnabled: Bool = false
        
        var isStarted: Bool {
            channel?.isActive ?? false
        }
        
        init(
            port: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            timeTagMode: OSCTimeTagMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            _localPort = (port == nil || port == 0) ? nil : port
            self.interface = interface
            self.isPortReuseEnabled = isPortReuseEnabled
            self.timeTagMode = timeTagMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPServer.queue")
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
        guard !isStarted else { return }
        
        stop()
        
        let handler = OSCUDPChannelHandler(oscServer: self)
        let host: String = interface ?? "0.0.0.0"
        let port: UInt16 = _localPort ?? 0
        
        let reuseAddress: ChannelOptions.Types.SocketOption.Value = isPortReuseEnabled ? 1 : 0
        channel = try DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .channelOption(.socketOption(.so_reuseaddr), value: reuseAddress)
            .channelInitializer { channel in
                channel.pipeline.addHandler(handler)
            }
            .bind(host: host, port: Int(port))
            .wait()
    }
    
    func stop() {
        channel?.close(promise: nil)
        channel = nil
    }
}

// MARK: - Communication

extension OSCUDPServer.Core: _OSCHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

// MARK: - Properties

extension OSCUDPServer.Core {
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
}

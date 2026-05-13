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

        private var channel: (any Channel)?
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?

        var timeTagMode: OSCTimeTagMode

        var remoteHost: String?

        var localPort: UInt16 {
            if let port = channel?.localAddress?.port {
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

        var isStarted: Bool {
            channel?.isActive ?? false
        }

        init(
            localPort: UInt16?,
            remoteHost: String?,
            remotePort: UInt16?,
            interface: String?,
            timeTagMode: OSCTimeTagMode,
            isIPv4BroadcastEnabled: Bool,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            self.remoteHost = remoteHost
            _localPort = (localPort == nil || localPort == 0) ? nil : localPort
            _remotePort = (remotePort == nil || remotePort == 0) ? nil : remotePort
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.isIPv4BroadcastEnabled = isIPv4BroadcastEnabled
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCUDPSocket.queue")
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
        guard !isStarted else { return }

        let group = MultiThreadedEventLoopGroup(numberOfThreads: 1)
        let broadcast: ChannelOptions.Types.SocketOption.Value = isIPv4BroadcastEnabled ? 1 : 0
        var bootstrap = DatagramBootstrap(group: group)
            .channelOption(.socketOption(.so_broadcast), value: broadcast)
            .channelInitializer { channel in
                channel.pipeline.addHandler(OSCUDPChannelHandler(oscServer: self))
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
        try? channel?.close().wait()
        channel = nil
    }
}

// MARK: - Communication

extension OSCUDPSocket.Core: _OSCHandlerProtocol {
    // provides implementation for dispatching incoming OSC data
}

extension OSCUDPSocket.Core {
    func send(_ packet: OSCPacket, to host: String?, port: UInt16?) throws {
        guard let channel, isStarted else {
            throw OSCIOError.notStarted
        }

        guard let toHost = host ?? remoteHost else {
            throw OSCIOError.noRemoteHost
        }

        let data = try packet.rawData()

        let port = Int(port ?? remotePort)

        let remoteAddress = try SocketAddress.makeAddressResolvingHost(toHost, port: port)

        let buffer: ByteBuffer = channel.allocator.buffer(bytes: data)

        let envelope = AddressedEnvelope(remoteAddress: remoteAddress, data: buffer)

        try channel.writeAndFlush(envelope).wait()
    }
}

// MARK: - Properties

extension OSCUDPSocket.Core {
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        queue.async {
            self.receiveHandler = handler
        }
    }
}

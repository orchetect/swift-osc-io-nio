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

        var isStarted: Bool {
            channel?.isActive ?? false
        }

        init(
            localPort: UInt16?,
            interface: String?,
            isPortReuseEnabled: Bool,
            isIPv4BroadcastEnabled: Bool
        ) {
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
        guard !isStarted else { return }

        stop()

        let reuseAddress: ChannelOptions.Types.SocketOption.Value = isPortReuseEnabled ? 1 : 0
        let broadcast: ChannelOptions.Types.SocketOption.Value = _isIPv4BroadcastEnabled ? 1 : 0

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
            host = "localhost"
        }

        let port = Int(_localPort ?? 0)

        // Channel Setup
        let bootstrap = DatagramBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            // configure port reuse
            .channelOption(.socketOption(.so_reuseaddr), value: reuseAddress)
            // configure ipv4 broadcast
            .channelOption(.socketOption(.so_broadcast), value: broadcast)

        channel = try bootstrap
            // bind to host and port
            .bind(host: host, port: port)
            // wait for resolution of the `EventLoopFuture`
            .wait()
    }

    func stop() {
        // close channel -> opportunity for completion handler
        channel?.close(promise: nil)
        channel = nil
    }
}

// MARK: - Communication

extension OSCUDPClient.Core {
    func send(_ packet: OSCPacket, to host: String, port: UInt16) throws {
        let data = try packet.rawData()

        if !isStarted {
            try start()
        }

        guard let channel else {
            throw OSCIOError.notStarted
        }

        // resolve host and port to `SocketAddress`
        let remoteAddress = try SocketAddress.makeAddressResolvingHost(host, port: Int(port))
        // create buffer from data
        let buffer: ByteBuffer = channel.allocator.buffer(bytes: data)

        let envelope = AddressedEnvelope(remoteAddress: remoteAddress, data: buffer)
        channel.writeAndFlush(envelope, promise: nil)
    }
}

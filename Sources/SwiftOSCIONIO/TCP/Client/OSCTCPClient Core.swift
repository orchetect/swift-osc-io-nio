//
//  OSCTCPClient Core.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCIOCore
internal import SwiftOSCIOInternals

extension OSCTCPClient {
    /// Internal operations class so as to not expose I/O implementation details as public.
    final class Core {
        typealias Parent = OSCTCPClient
        
        var channel: (any Channel)?
        let queue: DispatchQueue
        var receiveHandler: OSCHandlerBlock?
        var notificationHandler: Parent.NotificationHandlerBlock?
        
        var timeTagMode: OSCTimeTagMode
        let remoteHost: String
        let remotePort: UInt16
        let interface: String?
        var isConnected: Bool {
            channel?.isActive ?? false
        }
        let framingMode: OSCTCPFramingMode
        
        init(
            remoteHost: String,
            remotePort: UInt16,
            interface: String?,
            timeTagMode: OSCTimeTagMode,
            framingMode: OSCTCPFramingMode,
            queue: DispatchQueue?,
            receiveHandler: OSCHandlerBlock?
        ) {
            self.remoteHost = remoteHost
            self.remotePort = remotePort
            self.interface = interface
            self.timeTagMode = timeTagMode
            self.framingMode = framingMode
            let queue = queue ?? DispatchQueue(label: "com.orchetect.SwiftOSC.OSCTCPClient.queue")
            self.queue = queue
            self.receiveHandler = receiveHandler
        }
        
        deinit {
            close()
        }
    }
}

extension OSCTCPClient.Core: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPClient.Core {
    func connect(timeout: TimeInterval = 5.0) throws {
        // negative values mean indefinite (no timeout) which is a bit dangerous
        let timeout = Int64(max(1.0, timeout))
        
        let handler = ChannelHandler(oscServer: self)
        // create the client bootstrap
        let bootstrap = ClientBootstrap(group: .singletonMultiThreadedEventLoopGroup)
            .connectTimeout(.seconds(timeout))
            .channelInitializer { channel in
                channel.eventLoop.makeCompletedFuture {
                    // chose which decoder to use
                    switch self.framingMode {
                    case .osc1_0: // Length Header
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(OSCTCPLengthHeaderFrameDecoder()))
                    case .osc1_1: // SLIP
                        try channel.pipeline.syncOperations.addHandler(ByteToMessageHandler(OSCTCPSLIPFrameDecoder()))
                    }
                    // add client handler
                    try channel.pipeline.syncOperations.addHandler(handler)
                }
            }
        
        // connect to host
        channel = try bootstrap
            .connect(host: remoteHost, port: Int(remotePort))
            .wait()
    }
    
    func close() {
        // close the connection
        channel?.close(promise: nil)
        // deallocate channel
        channel = nil
    }
}

// MARK: - Communication

extension OSCTCPClient.Core: _OSCTCPHandlerProtocol {
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
}

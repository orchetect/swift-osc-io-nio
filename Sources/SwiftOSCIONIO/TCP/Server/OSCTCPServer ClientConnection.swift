//
//  OSCTCPServer ClientConnection.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
internal import SwiftOSCIOInternals

extension OSCTCPServer {
    /// Internal class encapsulating a remote client connection session accepted by a local ``OSCTCPServer``.
    final class ClientConnection {
        let channel: (any Channel)?
        let oscServer: (any _OSCTCPHandlerProtocol & _OSCTCPGeneratesServerNotificationsProtocol)?
        let clientID: OSCTCPClientSessionID
        let remoteHost: String // cached, since Channel resets it upon disconnection
        let remotePort: UInt16 // cached, since Channel resets it upon disconnection
        let framingMode: OSCTCPFramingMode

        init(
            server: any _OSCTCPHandlerProtocol & _OSCTCPGeneratesServerNotificationsProtocol,
            channel: any Channel,
            clientID: OSCTCPClientSessionID,
            framingMode: OSCTCPFramingMode
        ) {
            self.channel = channel
            oscServer = server
            self.clientID = clientID
            remoteHost = channel.remoteAddress?.ipAddress ?? ""
            remotePort = UInt16(channel.remoteAddress?.port ?? 0)
            self.framingMode = framingMode
        }

        deinit {
            close()
        }
    }
}

extension OSCTCPServer.ClientConnection: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer.ClientConnection {
    func close() {
        channel?.close(promise: nil)
    }
}

// MARK: - Communication

extension OSCTCPServer.ClientConnection: _OSCTCPSendProtocol {
    func send(_ oscPacket: OSCPacket) throws {
        try _send(oscPacket)
    }
}

extension OSCTCPServer.ClientConnection: _OSCTCPHandlerProtocol {
    var queue: DispatchQueue {
        oscServer?.queue ?? .global()
    }

    var timeTagMode: OSCTimeTagMode {
        oscServer?.timeTagMode ?? .ignore
    }

    var receiveHandler: OSCHandlerBlock? {
        oscServer?.receiveHandler
    }
    
    func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        oscServer?.setReceiveHandler(handler)
    }
}

extension OSCTCPServer.ClientConnection: OSCTCPGeneratesClientNotificationsProtocol {
    func generateConnectedNotification() {
        oscServer?._generateConnectedNotification(
            remoteHost: remoteHost,
            remotePort: remotePort,
            clientID: clientID
        )
    }

    func generateDisconnectedNotification(error: (any Error)?) {
        oscServer?._generateDisconnectedNotification(
            remoteHost: remoteHost,
            remotePort: remotePort,
            clientID: clientID,
            error: error
        )
    }
}

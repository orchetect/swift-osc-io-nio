//
//  OSCTCPServer.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore
internal import SwiftOSCIOInternals

public final class OSCTCPServer: OSCTCPServerProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        port: UInt16?,
        interface: String?,
        timeTagMode: OSCTimeTagMode,
        framingMode: OSCTCPFramingMode,
        queue: DispatchQueue?,
        receiveHandler: OSCHandlerBlock?
    ) {
        core = Core(
            port: port,
            interface: interface,
            timeTagMode: timeTagMode,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
    }
}

extension OSCTCPServer: @unchecked Sendable { } // TODO: unchecked

// MARK: - Lifecycle

extension OSCTCPServer {
    public func start() throws {
        try core.start()
    }

    public func stop() {
        core.stop()
    }
}

// MARK: - Communication

extension OSCTCPServer {
    public func send(_ packet: OSCPacket, toClientID clientID: OSCTCPClientSessionID) throws {
        try core.send(packet, toClientID: clientID)
    }
    
    public func send(
        _ packet: OSCPacket,
        toClientIDs clientIDs: [OSCTCPClientSessionID]?,
        errorHandler: ((_ clientID: OSCTCPClientSessionID, _ error: any Error) -> Void)?
    ) {
        core.send(packet, toClientIDs: clientIDs, errorHandler: errorHandler)
    }
}

// MARK: - Properties

extension OSCTCPServer {
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }
    
    public var localPort: UInt16 {
        core.localPort
    }
    
    public var interface: String? {
        core.interface
    }
    
    public var isStarted: Bool {
        core.isStarted
    }
    
    public var framingMode: OSCTCPFramingMode {
        core.framingMode
    }
    
    public func setReceiveHandler(_ handler: OSCHandlerBlock?) {
        core.setReceiveHandler(handler)
    }
    
    public func setNotificationHandler(_ handler: NotificationHandlerBlock?) {
        core.setNotificationHandler(handler)
    }
    
    public var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        core.clients
    }
    
    public func disconnectClient(clientID: OSCTCPClientSessionID) {
        core.disconnectClient(clientID: clientID)
    }
}

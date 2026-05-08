//
//  NIOOSCTCPClient.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import SwiftOSCIOCore

public final class NIOOSCTCPClient: OSCTCPClientProtocol {
    /// Internal operations core.
    let core: Core
    
    public init(
        remoteHost: String,
        remotePort: UInt16,
        interface: String?,
        timeTagMode: OSCTimeTagMode,
        framingMode: OSCTCPFramingMode,
        queue: DispatchQueue?,
        receiveHandler: OSCHandlerBlock?
    ) {
        core = Core(
            remoteHost: remoteHost,
            remotePort: remotePort,
            interface: interface,
            timeTagMode: timeTagMode,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
    }
}

extension NIOOSCTCPClient: Sendable { }

// MARK: - Lifecycle

extension NIOOSCTCPClient {
    public func connect(timeout: TimeInterval) throws {
        try core.connect(timeout: timeout)
    }
    
    public func close() {
        core.close()
    }
}

// MARK: - Communication

extension NIOOSCTCPClient {
    public func send(_ packet: OSCPacket) throws {
        try core.send(packet)
    }
    
    public func send(_ bundle: OSCBundle) throws {
        try core.send(.bundle(bundle))
    }
    
    public func send(_ message: OSCMessage) throws {
        try core.send(.message(message))
    }
}

// MARK: - Properties

extension NIOOSCTCPClient {
    public var timeTagMode: OSCTimeTagMode {
        get { core.timeTagMode }
        set { core.timeTagMode = newValue }
    }
    
    public var remoteHost: String {
        core.remoteHost
    }
    
    public var remotePort: UInt16 {
        core.remotePort
    }
    
    public var interface: String? {
        core.interface
    }
    
    public var isConnected: Bool {
        core.isConnected
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
}

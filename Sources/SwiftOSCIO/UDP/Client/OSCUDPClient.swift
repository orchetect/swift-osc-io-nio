//
//  OSCUDPClient.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import SwiftOSCIOCore

public final class OSCUDPClient: OSCUDPClientProtocol {
    /// Internal operations core.
    let core: Core
    
    public init(
        localPort: UInt16?,
        interface: String?,
        isPortReuseEnabled: Bool,
        isIPv4BroadcastEnabled: Bool
    ) {
        core = Core(
            localPort: localPort,
            interface: interface,
            isPortReuseEnabled: isPortReuseEnabled,
            isIPv4BroadcastEnabled: isIPv4BroadcastEnabled
        )
    }
    
    // MARK: - Lifecycle
    
    public func start() throws {
        try core.start()
    }
    
    public func stop() {
        core.stop()
    }
    
    // MARK: - Communication
    
    public func send(_ packet: OSCPacket, to host: String, port: UInt16) throws {
        try core.send(packet, to: host, port: port)
    }
    
    // MARK: - Properties
    
    public var localPort: UInt16 {
        core.localPort
    }
    
    public var interface: String? {
        core.interface
    }
    
    public var isPortReuseEnabled: Bool {
        get { core.isPortReuseEnabled }
        set { core.isPortReuseEnabled = newValue }
    }
    
    public var isIPv4BroadcastEnabled: Bool {
        get { core.isIPv4BroadcastEnabled }
        set { core.isIPv4BroadcastEnabled = newValue }
    }
    
    public var isStarted: Bool {
        core.isStarted
    }
}

extension OSCUDPClient: Sendable { }

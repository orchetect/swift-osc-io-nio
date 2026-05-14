//
//  OSCTCPClient.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import SwiftOSCIOCore

public final class OSCTCPClient: OSCTCPClientProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        remoteHost: String,
        remotePort: UInt16,
        interface: String?,
        framingMode: OSCTCPFramingMode,
        queue: DispatchQueue?,
        receiveHandler: OSCPacketHandler?
    ) {
        core = Core(
            remoteHost: remoteHost,
            remotePort: remotePort,
            interface: interface,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
        )
    }

    // MARK: - Lifecycle

    public func connect(timeout: TimeInterval) throws {
        try core.connect(timeout: timeout)
    }

    public func close() {
        core.close()
    }

    // MARK: - Communication

    public func send(_ packet: OSCPacket) throws {
        try core.send(packet)
    }

    // MARK: - Properties

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

    public func setReceiveHandler(_ handler: OSCPacketHandler?) {
        core.setReceiveHandler(handler)
    }

    public func setNotificationHandler(_ handler: NotificationHandlerBlock?) {
        core.setNotificationHandler(handler)
    }
}

extension OSCTCPClient: Sendable { }

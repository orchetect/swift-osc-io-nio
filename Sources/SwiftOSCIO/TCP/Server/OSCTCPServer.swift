//
//  OSCTCPServer.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

internal import SwiftOSCIOInternals
import Foundation
import NIO
import SwiftOSCCore

public final class OSCTCPServer: OSCTCPServerProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        port: UInt16?,
        interface: String?,
        framingMode: OSCTCPFramingMode,
        queue: DispatchQueue?,
        receiveHandler: OSCPacketHandler?
    ) {
        core = Core(
            port: port,
            interface: interface,
            framingMode: framingMode,
            queue: queue,
            receiveHandler: receiveHandler
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

    // MARK: - Properties

    public var localPort: UInt16 {
        core.localPort
    }

    public var interface: String? {
        core.interface
    }

    public var isIPv6Enabled: Bool {
        get { core.isIPv6Enabled }
        set { core.isIPv6Enabled = newValue }
    }

    public var isStarted: Bool {
        core.isStarted
    }

    public var framingMode: OSCTCPFramingMode {
        core.framingMode
    }

    public var clients: [OSCTCPClientSessionID: (host: String, port: UInt16)] {
        core.clients
    }

    public func disconnectClient(clientID: OSCTCPClientSessionID) {
        core.disconnectClient(clientID: clientID)
    }

    public func setReceiveHandler(_ handler: OSCPacketHandler?) {
        core.setReceiveHandler(handler)
    }

    public func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        core.setReceiveErrorHandler(handler)
    }

    public func setNotificationHandler(_ handler: NotificationHandlerBlock?) {
        core.setNotificationHandler(handler)
    }
}

extension OSCTCPServer: Sendable { }

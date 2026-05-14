//
//  OSCUDPServer.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import SwiftOSCCore

public final class OSCUDPServer: OSCUDPServerProtocol {
    /// Internal operations core.
    let core: Core

    public init(
        port: UInt16?,
        interface: String?,
        isPortReuseEnabled: Bool,
        queue: DispatchQueue?,
        receiveHandler: OSCPacketHandler?
    ) {
        core = Core(
            port: port,
            interface: interface,
            isPortReuseEnabled: isPortReuseEnabled,
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

    public var isStarted: Bool {
        core.isStarted
    }

    public func setReceiveHandler(_ handler: OSCPacketHandler?) {
        core.setReceiveHandler(handler)
    }

    public func setReceiveErrorHandler(_ handler: OSCDecodeErrorHandlerBlock?) {
        core.setReceiveErrorHandler(handler)
    }
}

extension OSCUDPServer: Sendable { }

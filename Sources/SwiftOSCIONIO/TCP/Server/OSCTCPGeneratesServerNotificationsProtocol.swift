//
//  OSCTCPGeneratesServerNotificationsProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if !os(watchOS)

protocol _OSCTCPGeneratesServerNotificationsProtocol {
    func _generateConnectedNotification(
        remoteHost: String,
        remotePort: Int,
        clientID: OSCTCPClientSessionID
    )

    func _generateDisconnectedNotification(
        remoteHost: String,
        remotePort: Int,
        clientID: OSCTCPClientSessionID,
        error: (any Error)?
    )
}

#endif

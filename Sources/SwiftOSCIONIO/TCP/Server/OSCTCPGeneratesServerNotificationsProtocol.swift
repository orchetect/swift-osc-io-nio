//
//  OSCTCPGeneratesServerNotificationsProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

protocol _OSCTCPGeneratesServerNotificationsProtocol {
    func _generateConnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID
    )

    func _generateDisconnectedNotification(
        remoteHost: String,
        remotePort: UInt16,
        clientID: OSCTCPClientSessionID,
        error: (any Error)?
    )
}

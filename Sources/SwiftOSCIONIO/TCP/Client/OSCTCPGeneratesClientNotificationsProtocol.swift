//
//  OSCTCPGeneratesClientNotificationsProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

protocol _OSCTCPGeneratesClientNotificationsProtocol {
    func _generateConnectedNotification()

    func _generateDisconnectedNotification(
        error: (any Error)?
    )
}

//
//  OSCTCPGeneratesServerNotificationsProtocol.swift
//  SwiftOSCCore • https://github.com/orchetect/SwiftOSCCore
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
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

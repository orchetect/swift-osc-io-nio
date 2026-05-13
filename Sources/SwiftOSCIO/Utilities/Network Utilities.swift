//
//  Network Utilities.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import NIOCore

/// Returns network devices in the system that have an address.
func networkDevices() throws -> [(name: String, address: SocketAddress)] {
    try System
        .enumerateDevices()
        .compactMap { device -> (name: String, address: SocketAddress)? in
            guard let address = device.address else { return nil }
            return (name: device.name, address: address)
        }
}

/// Returns the first network device that carries an IPv4 address with a name or address that matches the given string.
func networkDevices(
    matchingNameOrAddress interface: String,
    protocols: [NIOBSDSocket.ProtocolFamily]? = nil
) throws -> [(name: String, address: SocketAddress)] {
    var devices = try networkDevices()

    if let protocols {
        devices = devices
            .filter { protocols.contains($0.address.protocol) }
    }

    return devices.filter {
        $0.name == interface || $0.address.ipAddress == interface
    }
}

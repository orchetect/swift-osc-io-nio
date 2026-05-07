//
//  OSCTCPSendProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore

/// Internal protocol that TCP-based OSC classes adopt in order to send OSC packets.
protocol _OSCTCPSendProtocol: AnyObject where Self: Sendable {
    var channel: (any Channel)? { get }
    var framingMode: OSCTCPFramingMode { get }
}

extension _OSCTCPSendProtocol {
    /// Send an OSC packet.
    ///
    /// - Parameters:
    ///   - oscPacket: OSC bundle or message.
    func _send(_ oscPacket: OSCPacket) throws {
        try _send(oscPacket.rawData())
    }

    /// Send an OSC bundle.
    ///
    /// - Parameters:
    ///   - oscBundle: OSC bundle.
    func _send(_ oscBundle: OSCBundle) throws {
        try _send(oscBundle.rawData())
    }

    /// Send an OSC message.
    ///
    /// - Parameters:
    ///   - oscMessage: OSC message.
    func _send(_ oscMessage: OSCMessage) throws {
        try _send(oscMessage.rawData())
    }

    /// Send an OSC packet.
    ///
    /// - Parameters:
    ///   - oscData: Raw bytes of an OSC bundle or message.
    private func _send(_ oscData: Data) throws(OSCTCPClientError) {
        guard let channel else {
            throw OSCTCPClientError.notStarted
        }

        // frame data
        let data = framingMode.encode(data: oscData)

        // send packet
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        channel.writeAndFlush(buffer, promise: nil)
    }
}

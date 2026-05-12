//
//  OSCTCPSendProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore
import SwiftOSCIOCore

/// Internal protocol that TCP-based OSC classes adopt in order to send OSC packets.
protocol _OSCTCPSendProtocol: AnyObject where Self: Sendable {
    var channel: (any Channel)? { get }
    var framingMode: OSCTCPFramingMode { get }
}

extension _OSCTCPSendProtocol {
    func _send(_ packet: OSCPacket) throws {
        try _send(packet.rawData())
    }

    private func _send(_ oscData: Data) throws(OSCIOError) {
        guard let channel else {
            throw OSCIOError.notStarted
        }

        // frame data
        let data = framingMode.encode(data: oscData)

        // send packet
        var buffer = channel.allocator.buffer(capacity: data.count)
        buffer.writeBytes(data)
        channel.writeAndFlush(buffer, promise: nil)
    }
}

//
//  OSCTCPPacketLengthHeaderDecodingError.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import protocol Foundation.LocalizedError

/// Error cases thrown while decoding packet data encoded with packet-length header framing.
public enum OSCTCPPacketLengthHeaderDecodingError: LocalizedError, Equatable, Hashable {
    case notEnoughBytes

    public var errorDescription: String? {
        switch self {
        case .notEnoughBytes:
            "Not enough bytes."
        }
    }
}

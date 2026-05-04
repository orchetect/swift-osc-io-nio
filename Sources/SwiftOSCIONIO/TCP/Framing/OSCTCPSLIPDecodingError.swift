//
//  OSCTCPSLIPDecodingError.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import protocol Foundation.LocalizedError

/// Error cases thrown while decoding packet data encoded with the SLIP protocol (RFC 1055).
public enum OSCTCPSLIPDecodingError: LocalizedError, Equatable, Hashable {
    case doubleEscapeBytes
    case missingEscapedCharacter

    public var errorDescription: String? {
        switch self {
        case .doubleEscapeBytes:
            "SLIP packet data is malformed. Double escape bytes encountered."
        case .missingEscapedCharacter:
            "SLIP packet data is malformed. Encountered an escape byte but missing subsequent escaped character."
        }
    }
}

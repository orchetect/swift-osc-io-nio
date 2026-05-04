//
//  OSCHandlerBlock.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import SwiftOSCCore

/// Received-message handler closure used by SwiftOSCIONIO socket classes.
public typealias OSCHandlerBlock = @Sendable (
    _ message: OSCMessage,
    _ timeTag: OSCTimeTag,
    _ host: String,
    _ port: Int
) -> Void

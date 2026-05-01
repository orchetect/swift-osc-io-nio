//
//  OSCHandlerBlock.swift
//  SwiftOSCCore • https://github.com/orchetect/SwiftOSCCore
//  © 2020-2026 Steffan Andrews • Licensed under MIT License
//

#if !os(watchOS)

import SwiftOSCCore

/// Received-message handler closure used by SwiftOSCCore socket classes.
public typealias OSCHandlerBlock = @Sendable (
    _ message: OSCMessage,
    _ timeTag: OSCTimeTag,
    _ host: String,
    _ port: Int
) -> Void

#endif

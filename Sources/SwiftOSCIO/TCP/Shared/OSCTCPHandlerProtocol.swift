//
//  OSCTCPHandlerProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

import Foundation
import NIO
import SwiftOSCCore
import SwiftOSCIOCore
internal import SwiftOSCIOInternals

/// Internal protocol that TCP-based OSC classes adopt in order to handle incoming OSC data.
protocol _OSCTCPHandlerProtocol: OSCTCPHandlerProtocol {
    var channel: (any Channel)? { get }
}

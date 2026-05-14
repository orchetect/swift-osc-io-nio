//
//  OSCTCPPacketDispatcherProtocol.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

internal import SwiftOSCIOInternals
import Foundation
import NIO
import SwiftOSCCore
import SwiftOSCIOCore

/// Internal protocol that TCP-based OSC classes adopt in order to handle incoming OSC data.
protocol _OSCTCPPacketDispatcherProtocol: OSCTCPPacketDispatcherProtocol {
    var channel: (any Channel)? { get }
}

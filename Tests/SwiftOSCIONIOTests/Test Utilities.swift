//
//  Test Utilities.swift
//  SwiftOSC I/O: SwiftNIO • https://github.com/orchetect/swift-osc-io-nio
//  © 2026 Steffan Andrews • Licensed under MIT License
//

#if !os(watchOS)

import Foundation
import SwiftOSCCore
import Testing

func wait(
    expect condition: @Sendable () async throws -> Bool,
    timeout: TimeInterval,
    pollingInterval: TimeInterval = 0.1,
    _ comment: Testing.Comment? = nil,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async rethrows {
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
        if try await condition() { return }
        try? await Task.sleep(seconds: pollingInterval)
    }

    #expect(try await condition(), comment, sourceLocation: sourceLocation)
}

func wait(
    require condition: @Sendable () async throws -> Bool,
    timeout: TimeInterval,
    pollingInterval: TimeInterval = 0.1,
    _ comment: Testing.Comment? = nil,
    sourceLocation: Testing.SourceLocation = #_sourceLocation
) async throws {
    let startTime = Date()

    while Date().timeIntervalSince(startTime) < timeout {
        if try await condition() { return }
        try await Task.sleep(seconds: pollingInterval)
    }

    try #require(await condition(), comment, sourceLocation: sourceLocation)
}

/// Use as a condition for individual tests that rely on stable/precise system timing.
func isSystemTimingStable(
    duration: TimeInterval = 0.1,
    tolerance: TimeInterval = 0.01
) -> Bool {
    let start = Date()
    Thread.sleep(forTimeInterval: duration)
    let end = Date()
    let diff = end.timeIntervalSince(start)

    let range = (duration - tolerance) ... (duration + tolerance)
    return range.contains(diff)
}

private let maxSeconds = TimeInterval(UInt64.max / 1_000_000_000)

@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
extension Task where Success == Never, Failure == Never {
    /// Suspends the current task for at least the given duration in seconds.
    package static func sleep(seconds: TimeInterval) async throws {
        // safety check: protect again overflow

        let secondsClamped = min(seconds, maxSeconds)
        let nanoseconds = UInt64(secondsClamped * 1_000_000_000)

        try await sleep(nanoseconds: nanoseconds)
    }
}

extension BinaryInteger {
    /// Returns an integer as a hex string.
    /// Prefix optional.
    package func hexString(prefix: Bool = true) -> String {
        (prefix ? "0x" : "")
        + String(self, radix: 16, uppercase: true)
    }
}

#endif

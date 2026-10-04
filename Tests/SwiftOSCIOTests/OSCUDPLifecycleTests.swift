import Foundation
import SwiftOSCIO
import Testing

@Suite
struct OSCUDPLifecycleTests {
    @Test
    func deinit_WhenReleasedOnDeliveryQueue_DoesNotDeadlock() async {
        let queue = DispatchQueue(
            label: "com.orchetect.SwiftOSC.Tests.OSCUDPServer.delivery"
        )

        await withCheckedContinuation { continuation in
            queue.async {
                // Recursive `.messages` bundle dispatch can make a queued
                // delivery closure the final owner of Core. Releasing the
                // server directly on its delivery queue deterministically
                // reproduces that terminal lifecycle condition without
                // relying on network traffic or scheduling timing.
                createAndReleaseServer(on: queue)

                continuation.resume()
            }
        }
    }
}

// MARK: - Helpers

private func createAndReleaseServer(on queue: DispatchQueue) {
    let server = OSCUDPServer(
        port: nil,
        interface: nil,
        isPortReuseEnabled: false,
        isIPv6Enabled: false,
        queue: queue,
        receiveHandler: nil
    )

    withExtendedLifetime(server) {}
}

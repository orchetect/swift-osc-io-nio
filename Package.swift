// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "swift-osc-io-nio",
    platforms: [.macOS(.v10_15), .iOS(.v13), .tvOS(.v13), .watchOS(.v6)],
    products: [
        .library(name: "SwiftOSCIONIO", targets: ["SwiftOSCIONIO"])
    ],
    dependencies: [
        .package(url: "https://github.com/orchetect/swift-osc-core", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-nio", from: "2.87.0") // lowest version that supports Swift 6.0
        // .package(url: "https://github.com/apple/swift-numerics", from: "1.1.1"),
        // .package(url: "https://github.com/orchetect/swift-testing-extensions", from: "0.3.0")
    ],
    targets: [
        .target(
            name: "SwiftOSCIONIO",
            dependencies: [
                .product(name: "SwiftOSCCore", package: "swift-osc-core"),
                .product(name: "NIO", package: "swift-nio")
            ],
            swiftSettings: [.define("DEBUG", .when(configuration: .debug))]
        ),
        .testTarget(
            name: "SwiftOSCIONIOTests",
            dependencies: [
                "SwiftOSCIONIO",
                // .product(name: "Numerics", package: "swift-numerics"),
                // .product(name: "TestingExtensions", package: "swift-testing-extensions")
            ]
        )
    ]
)

// MARK: - Environment

#if canImport(Foundation) || canImport(CoreFoundation)
    #if canImport(Foundation)
        import class Foundation.ProcessInfo

        func getEnvironmentVar(_ name: String) -> String? {
            ProcessInfo.processInfo.environment[name]
        }

    #elseif canImport(CoreFoundation)
        import CoreFoundation

        func getEnvironmentVar(_ name: String) -> String? {
            guard let rawValue = getenv(name) else { return nil }
            return String(utf8String: rawValue)
        }
    #endif

    func isEnvironmentVarTrue(_ name: String) -> Bool {
        guard let value = getEnvironmentVar(name)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        else { return false }
        return ["true", "yes", "1"].contains(value.lowercased())
    }

    // MARK: - CI Pipeline

    if isEnvironmentVarTrue("GITHUB_ACTIONS") {
        for target in package.targets.filter(\.isTest) {
            if target.swiftSettings == nil { target.swiftSettings = [] }
            target.swiftSettings? += [.define("GITHUB_ACTIONS", .when(configuration: .debug))]
        }
    }
#endif

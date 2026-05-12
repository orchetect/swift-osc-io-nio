![SwiftOSC I/O: SwiftNIO](Images/swift-osc-io-nio-banner.png)

# SwiftOSC I/O: SwiftNIO

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Forchetect%2Fswift-osc-io-nio%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/orchetect/swift-osc-io-nio) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Forchetect%2Fswift-osc-io-nio%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/orchetect/swift-osc-io-nio) [![License: MIT](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/orchetect/swift-osc-io-nio/blob/main/LICENSE)

Network I/O extension for [SwiftOSCCore](https://github.com/orchetect/swift-osc-core) targeting Apple, Linux and Android platforms using [SwiftNIO](https://github.com/apple/swift-nio) as a backend.

## Compatibility

| macOS | iOS  | tvOS | visionOS | watchOS | Linux | Android | WASM | Windows |
| :---: | :--: | :--: | :------: | :-----: | :---: | :-----: | :-----: | :-----: |
|   🟢   |  🟢   |  🟢   |    🟢     |    🟢    |   🟢   |    🟢    |    -    |    -    |

## Getting Started

This extension is available as a Swift Package Manager (SPM) package.

To use this extension as standalone dependency (instead of importing the **swift-osc** umbrella repository):

1. Add the **swift-osc-io-nio** repo as a dependency.

   ```swift
   .package(url: "https://github.com/orchetect/swift-osc-io-nio", from: "1.0.0")
   ```

2. Add **SwiftOSCIO** to your target.

   ```swift
   .product(name: "SwiftOSCIO", package: "swift-osc-io-nio")
   ```

3. Import **SwiftOSCIO** to use it.

   ```swift
   import SwiftOSCIO
   ```

## Documentation

For I/O API documentation, see the [SwiftOSCCore online documentation](https://swiftpackageindex.com/orchetect/swift-osc-core/documentation/swiftosciocore) for this repository.

For example code see the main [SwiftOSC](https://github.com/orchetect/swift-osc) repository.

## Support

For support, feature requests and bug reports see the main [SwiftOSC](https://github.com/orchetect/swift-osc) repository.

## Author

Coded by a bunch of 🐹 hamsters in a trenchcoat that calls itself [@orchetect](https://github.com/orchetect).

SwiftNIO porting by [@The-Wolfson](https://github.com/The-Wolfson).

## License

Licensed under the MIT license. See [LICENSE](LICENSE) for details.

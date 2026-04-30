![SwiftOSC I/O: SwiftNIO](Images/swift-osc-io-nio-banner.png)

# SwiftOSC I/O: SwiftNIO

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Forchetect%2Fswift-osc-io-nio%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/orchetect/swift-osc-io-nio) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Forchetect%2Fswift-osc-io-nio%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/orchetect/swift-osc-io-nio) [![License: MIT](http://img.shields.io/badge/license-MIT-lightgrey.svg?style=flat)](https://github.com/orchetect/swift-osc-io-nio/blob/main/LICENSE)

Network I/O extension for [SwiftOSCCore](https://github.com/orchetect/swift-osc-core) targeting Apple, Linux and Android platforms using SwiftNIO as a backend.

## Compatibility

| macOS | iOS  | visionOS | Linux | Android | Windows |
| :---: | :--: | :------: | :---: | :-----: | :-----: |
|   🟢   |  🟢   |    🟢     |   🟢   |    🟢    |    -    |

## Getting Started

This extension is available as a Swift Package Manager (SPM) package.

To use this extension as standalone dependency (instead of importing the **swift-osc** umbrella repository):

1. Add the **swift-osc-io-nio** repo as a dependency.

   ```swift
   .package(url: "https://github.com/orchetect/swift-osc-io-nio", from: "1.0.0")
   ```

2. Add **SwiftOSCIONIO** to your target.

   ```swift
   .product(name: "SwiftOSCIONIO", package: "swift-osc-io-nio")
   ```

3. Import **SwiftOSCIONIO** to use it.

   ```swift
   import SwiftOSCIONIO
   ```

## Documentation

See the [online documentation](https://swiftpackageindex.com/orchetect/swift-osc-io-nio/main/documentation) for this repository. See one of the I/O extension repositories for example code.

For support, feature requests, and bug reports see the main [SwiftOSC](https://github.com/orchetect/swift-osc) repository.

## Dependencies

- [SwiftNIO](https://github.com/apple/swift-nio) is used for network sockets.
- [swift-ascii](https://github.com/orchetect/SwiftASCII) is used for ASCII string and character formatting and validation.
- [swift-data-parsing](https://github.com/orchetect/swift-data-parsing) is used for message decoding.

## Author

Coded by a bunch of 🐹 hamsters in a trenchcoat that calls itself [@orchetect](https://github.com/orchetect).

## License

Licensed under the MIT license. See [LICENSE](LICENSE) for details.

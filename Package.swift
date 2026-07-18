// swift-tools-version: 6.3
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "swift-embedded-foundation",
    // `UInt128` (used by the UUID shim) requires these minimums on Apple platforms.
    platforms: [
        .macOS(.v15),
        .iOS(.v18),
        .tvOS(.v18),
        .watchOS(.v11),
        .macCatalyst(.v18),
        .visionOS(.v2),
    ],
    products: [
        .library(
            name: "FoundationEmbedded",
            targets: ["FoundationEmbedded"]
        )
    ],
    targets: [
        .target(
            name: "FoundationEmbedded"
        ),
        .testTarget(
            name: "FoundationEmbeddedTests",
            dependencies: ["FoundationEmbedded"]
        ),
    ],
    swiftLanguageModes: [.v6]
)

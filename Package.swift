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
    traits: [
        .trait(
            name: "FloatingPointParsingShims",
            description: """
                Export the standard library's floating-point parsing runtime \
                stubs so `Double`/`Float`/`Float16` can be created from a \
                `String` under Embedded Swift. Required through Swift 6.3, \
                where those stubs are unresolved; unnecessary from Swift 6.4, \
                which parses floating-point strings natively in Embedded Swift. \
                Disable this trait on toolchains that provide the stubs \
                themselves, or to supply your own.
                """
        ),
        .default(enabledTraits: ["FloatingPointParsingShims"]),
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

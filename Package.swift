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
        ),
        // The C header a platform implements when `FoundationEmbedded` is
        // built with the `PlatformHooks` trait.
        .library(
            name: "FoundationEmbeddedPlatform",
            targets: ["FoundationEmbeddedPlatform"]
        ),
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
        .trait(
            name: "PlatformHooks",
            description: """
                Ask a platform for what the package cannot know by itself: \
                the clock, the user's time zone and locale, named time \
                zones, and calendar arithmetic in any calendar. The \
                package then calls the functions declared in \
                `FoundationEmbeddedPlatform.h`, which the platform must \
                define; the linker joins the two. Without this trait the \
                package reads the C library's clock and local time zone \
                where there is one, and is otherwise self-contained.
                """
        ),
        .default(enabledTraits: ["FloatingPointParsingShims"]),
    ],
    targets: [
        // What the package uses of the C library, where there is one: the
        // clock and the local time zone. Header only.
        .target(
            name: "FoundationEmbeddedShims"
        ),
        // The functions a platform defines. Header only.
        .target(
            name: "FoundationEmbeddedPlatform"
        ),
        .target(
            name: "FoundationEmbedded",
            dependencies: [
                "FoundationEmbeddedShims",
                .target(name: "FoundationEmbeddedPlatform", condition: .when(traits: ["PlatformHooks"])),
            ]
        ),
        // A platform for the tests: the header over Foundation itself.
        .target(
            name: "FoundationEmbeddedTestPlatform",
            dependencies: ["FoundationEmbeddedPlatform"],
            path: "Tests/FoundationEmbeddedTestPlatform"
        ),
        .testTarget(
            name: "FoundationEmbeddedTests",
            dependencies: [
                "FoundationEmbedded",
                .target(name: "FoundationEmbeddedTestPlatform", condition: .when(traits: ["PlatformHooks"])),
            ]
        ),
    ],
    swiftLanguageModes: [.v6]
)

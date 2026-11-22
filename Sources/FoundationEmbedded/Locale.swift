//
//  Locale.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Locale` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.Locale`.
//
//  Not API-complete — identifier-only, no locale-sensitive formatting.
//  Built with the `PlatformHooks` trait, `current` is the user's locale as
//  a platform has it (`FoundationEmbeddedPlatform.h`).
//

public struct Locale: Sendable, Hashable {

    /// The locale identifier, e.g. `"en_US_POSIX"`.
    public let identifier: String

    @inlinable
    public init(identifier: String) {
        self.identifier = identifier
    }
}

extension Locale {

    #if PlatformHooks
    /// The user's locale, as the platform has it.
    public static var current: Locale {
        Platform.currentLocale()
    }

    /// The user's languages in order of preference, as the platform has them.
    public static var preferredLanguages: [String] {
        Platform.preferredLanguages()
    }
    #else
    /// The POSIX locale.
    ///
    /// - Note: Unlike `Foundation.Locale.current`, this never reflects a
    ///   user-configured region. On a device without a locale database the
    ///   only meaningful, stable choice is the fixed POSIX locale.
    @inlinable
    public static var current: Locale {
        Locale(identifier: "en_US_POSIX")
    }
    #endif
}

// MARK: - CustomStringConvertible

extension Locale: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        identifier
    }

    public var debugDescription: String {
        description
    }
}

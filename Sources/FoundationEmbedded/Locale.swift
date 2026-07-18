//
//  Locale.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Locale` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.Locale`.
//
//  Not API-complete — identifier-only, no locale-sensitive formatting.
//

public struct Locale: Sendable, Hashable {

    /// The locale identifier, e.g. `"en_US_POSIX"`.
    public let identifier: String

    public init(identifier: String) {
        self.identifier = identifier
    }
}

extension Locale {

    /// The POSIX locale.
    ///
    /// - Note: Unlike `Foundation.Locale.current`, this never reflects a
    ///   user-configured region. On a device without a locale database the
    ///   only meaningful, stable choice is the fixed POSIX locale.
    public static var current: Locale {
        Locale(identifier: "en_US_POSIX")
    }
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

// MARK: - Codable

#if !hasFeature(Embedded)
extension Locale: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(identifier: try container.decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(identifier)
    }
}
#endif

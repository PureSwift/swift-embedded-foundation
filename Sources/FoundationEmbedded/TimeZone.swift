//
//  TimeZone.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `TimeZone` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.TimeZone`.
//
//  The package has no zone database. By itself it knows fixed offsets
//  from GMT, and the process's own zone where the C library has one
//  (`localtime_r`). Built with the `PlatformHooks` trait it asks a
//  platform about zones by name (`FoundationEmbeddedPlatform.h`).
//

#if PlatformHooks
import FoundationEmbeddedPlatform
#else
import FoundationEmbeddedShims
#endif

public struct TimeZone: Sendable, Hashable {

    /// The time-zone identifier, e.g. `"GMT"`.
    public let identifier: String

    /// The offset from GMT, in seconds, of a fixed-offset zone; 0 for any
    /// other.
    ///
    /// - Note: Internal. `Foundation.TimeZone` exposes the offset only through
    ///   `secondsFromGMT(for:)`, so this stays out of the public surface.
    @usableFromInline
    let secondsFromGMT: Int

    /// Where the zone's offset comes from.
    @usableFromInline
    let kind: Kind

    @usableFromInline
    enum Kind: UInt8, Sendable, Hashable {

        /// The offset in the identifier. It never changes.
        case fixed

        /// The process's zone, as the C library has it.
        case system

        /// A zone the platform knows by name.
        case named
    }

    /// Create a time zone with an explicit identifier.
    @usableFromInline
    init(identifier: String, secondsFromGMT: Int, kind: Kind = .fixed) {
        self.identifier = identifier
        self.secondsFromGMT = secondsFromGMT
        self.kind = kind
    }
}

extension TimeZone {

    /// Create a time zone from an identifier.
    ///
    /// Recognizes `"GMT"`, `"UTC"`, and `"GMT±HH:MM"` / `"GMT±HHMM"` offsets.
    /// With the `PlatformHooks` trait, also any name the platform knows, such
    /// as `"Europe/Berlin"`. Returns `nil` for anything else.
    public init?(identifier: String) {
        if identifier == "GMT" || identifier == "UTC" {
            self.init(identifier: identifier, secondsFromGMT: 0)
            return
        }
        if identifier.hasPrefix("GMT"), let seconds = TimeZone.parseGMTOffset(identifier) {
            self.init(identifier: identifier, secondsFromGMT: seconds)
            return
        }
        #if PlatformHooks
        guard Platform.isKnownTimeZone(identifier) else {
            return nil
        }
        self.init(identifier: identifier, secondsFromGMT: 0, kind: .named)
        #else
        return nil
        #endif
    }

    /// Create a fixed-offset time zone, naming it after the offset.
    ///
    /// Returns `nil` if the offset is beyond ±18 hours (matching Foundation).
    public init?(secondsFromGMT seconds: Int) {
        guard seconds >= -18 * 3600, seconds <= 18 * 3600 else {
            return nil
        }
        self.init(identifier: TimeZone.gmtIdentifier(forSeconds: seconds), secondsFromGMT: seconds)
    }

    /// The GMT (UTC) time zone.
    @inlinable
    public static var gmt: TimeZone {
        TimeZone(identifier: "GMT", secondsFromGMT: 0)
    }

    /// The current time zone.
    ///
    /// With the `PlatformHooks` trait, the user's zone as the platform has it.
    /// Without it, the process's zone as the C library has it, whose offset
    /// follows daylight saving; its `identifier` is the `TZ` variable's value,
    /// or `"Local"`, since the C library has no name for it. Where there is no
    /// C library, or it knows no zone (WASI), GMT.
    public static var current: TimeZone {
        #if PlatformHooks
        return Platform.currentTimeZone()
        #else
        var offset: Int32 = 0
        guard swift_embedded_shims_local_offset(0, &offset) else {
            return .gmt
        }
        var name = "Local"
        if let variable = swift_embedded_shims_timezone_name() {
            let value = String(cString: variable)
            // `:Europe/Berlin` is the same zone as `Europe/Berlin`.
            let trimmed = value.utf8.first == UInt8(ascii: ":") ? String(value.dropFirst()) : value
            if !trimmed.isEmpty {
                name = trimmed
            }
        }
        return TimeZone(identifier: name, secondsFromGMT: 0, kind: .system)
        #endif
    }

    private static func gmtIdentifier(forSeconds seconds: Int) -> String {
        if seconds == 0 {
            return "GMT"
        }
        let magnitude = seconds < 0 ? -seconds : seconds
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        
        // Match Foundation formatting: "GMT+0100" (no colon).
        // Use 8 bytes with temporary allocation to avoid heap allocation.
        // Doc: https://www.swift.org/blog/utf8-string/
        // swift-foundation example: https://tinyurl.com/FoundationEssentialsStringIO
        return withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 8) { utf8 in
            utf8[0] = UInt8(ascii: "G")
            utf8[1] = UInt8(ascii: "M")
            utf8[2] = UInt8(ascii: "T")
            utf8[3] = seconds < 0 ? UInt8(ascii: "-") : UInt8(ascii: "+")
            utf8[4] = UInt8(ascii: "0") + UInt8(hours / 10)
            utf8[5] = UInt8(ascii: "0") + UInt8(hours % 10)
            utf8[6] = UInt8(ascii: "0") + UInt8(minutes / 10)
            utf8[7] = UInt8(ascii: "0") + UInt8(minutes % 10)
            return String(decoding: utf8, as: UTF8.self)
        }
    }

    /// Parses the offset from a `GMT±HH:MM` / `GMT±HHMM` / `GMT±HH` identifier.
    ///
    /// Scans the UTF-8 in place: the previous implementation copied the
    /// identifier into an array, shifted it to drop the prefix, and collected
    /// the digits into a second array.
    private static func parseGMTOffset(_ identifier: String) -> Int? {
        var iterator = identifier.utf8.makeIterator()
        // Drop the "GMT" prefix, which the caller has already matched.
        _ = iterator.next()
        _ = iterator.next()
        _ = iterator.next()

        guard let signByte = iterator.next() else {
            return 0
        }
        let sign: Int
        switch signByte {
        case UInt8(ascii: "+"): sign = 1
        case UInt8(ascii: "-"): sign = -1
        default: return nil
        }

        // Accept "HH:MM", "HHMM", or "HH".
        var value = 0
        var digitCount = 0
        while let byte = iterator.next() {
            if byte == UInt8(ascii: ":") {
                continue
            }
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9"), digitCount < 4 else {
                return nil
            }
            value = value * 10 + Int(byte - UInt8(ascii: "0"))
            digitCount += 1
        }

        let hours: Int
        let minutes: Int
        switch digitCount {
        case 2:
            hours = value
            minutes = 0
        case 4:
            hours = value / 100
            minutes = value % 100
        default:
            return nil
        }
        guard minutes < 60 else { return nil }
        return sign * (hours * 3600 + minutes * 60)
    }
}

// MARK: - Offset Accessor

extension TimeZone {

    /// The offset from GMT, in seconds, for the given date.
    ///
    /// A fixed-offset zone ignores the date. Signature matches
    /// `Foundation.TimeZone.secondsFromGMT(for:)`.
    @inlinable
    public func secondsFromGMT(for date: Date) -> Int {
        kind == .fixed ? secondsFromGMT : variableSecondsFromGMT(for: date)
    }

    /// The offset of a zone whose offset changes: the process's, from the C
    /// library, or a named one, from the platform.
    @usableFromInline
    func variableSecondsFromGMT(for date: Date) -> Int {
        #if PlatformHooks
        return Platform.offset(of: self, at: date)
        #else
        var offset: Int32 = 0
        guard swift_embedded_shims_local_offset(date.timeIntervalSince1970, &offset) else {
            return 0
        }
        return Int(offset)
        #endif
    }
}

#if PlatformHooks

// MARK: - From the platform

extension TimeZone {

    /// Foundation's `NSTimeZone.NameStyle`.
    public enum NameStyle: Int, Sendable, Hashable {
        case standard = 0
        case shortStandard = 1
        case daylightSaving = 2
        case shortDaylightSaving = 3
        case generic = 4
        case shortGeneric = 5
    }

    /// Every time zone identifier the platform knows.
    public static var knownTimeZoneIdentifiers: [String] {
        Platform.timeZoneIdentifiers()
    }

    /// Whether daylight saving time is in effect at the given date.
    public func isDaylightSavingTime(for date: Date) -> Bool {
        daylightSavingTimeOffset(for: date) != 0
    }

    /// What daylight saving time adds at the given date; 0 outside it.
    public func daylightSavingTimeOffset(for date: Date) -> TimeInterval {
        kind == .fixed ? 0 : TimeInterval(Platform.daylightSavingOffset(of: self, at: date))
    }

    /// The next change of the zone's offset after the given date.
    public func nextDaylightSavingTimeTransition(after date: Date) -> Date? {
        kind == .fixed ? nil : Platform.nextTransition(of: self, after: date)
    }

    /// The zone's abbreviation at the given date, such as `"CET"`.
    public func abbreviation(for date: Date) -> String? {
        Platform.abbreviation(of: self, at: date)
    }

    /// The zone's name in a locale, such as `"Central European Time"`.
    public func localizedName(for style: NameStyle, locale: Locale?) -> String? {
        Platform.name(of: self, style: style, locale: locale)
    }
}

#endif

// MARK: - CustomStringConvertible

extension TimeZone: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        identifier
    }

    public var debugDescription: String {
        kind == .fixed ? "\(identifier) (\(secondsFromGMT)s from GMT)" : identifier
    }
}

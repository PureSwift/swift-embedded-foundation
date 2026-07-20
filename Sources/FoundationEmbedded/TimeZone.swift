//
//  TimeZone.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `TimeZone` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.TimeZone`.
//
//  Not API-complete — a fixed offset from GMT, no daylight-saving or
//  named-zone database.
//

public struct TimeZone: Sendable, Hashable {

    /// The time-zone identifier, e.g. `"GMT"`.
    public let identifier: String

    /// The offset from GMT, in seconds. Fixed — no daylight-saving transitions.
    ///
    /// - Note: Internal. `Foundation.TimeZone` exposes the offset only through
    ///   `secondsFromGMT(for:)`, so this stays out of the public surface.
    let secondsFromGMT: Int

    /// Create a fixed-offset time zone with an explicit identifier.
    init(identifier: String, secondsFromGMT: Int) {
        self.identifier = identifier
        self.secondsFromGMT = secondsFromGMT
    }
}

extension TimeZone {

    /// Create a time zone from an identifier.
    ///
    /// Recognizes `"GMT"`, `"UTC"`, and `"GMT±HH:MM"` / `"GMT±HHMM"` offsets.
    /// Returns `nil` for anything else, since there is no zone database.
    public init?(identifier: String) {
        if identifier == "GMT" || identifier == "UTC" {
            self.init(identifier: identifier, secondsFromGMT: 0)
            return
        }
        guard identifier.hasPrefix("GMT"),
            let seconds = TimeZone.parseGMTOffset(identifier)
        else {
            return nil
        }
        self.init(identifier: identifier, secondsFromGMT: seconds)
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
    public static var gmt: TimeZone {
        TimeZone(identifier: "GMT", secondsFromGMT: 0)
    }

    /// The current time zone.
    ///
    /// - Note: Without a system clock configuration this returns GMT, not a
    ///   user-configured zone.
    public static var current: TimeZone {
        .gmt
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
    /// This shim is a fixed offset, so the date is ignored. Signature matches
    /// `Foundation.TimeZone.secondsFromGMT(for:)`.
    public func secondsFromGMT(for date: Date) -> Int {
        secondsFromGMT
    }
}

// MARK: - CustomStringConvertible

extension TimeZone: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        identifier
    }

    public var debugDescription: String {
        "\(identifier) (\(secondsFromGMT)s from GMT)"
    }
}

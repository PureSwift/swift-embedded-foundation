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
        let sign = seconds < 0 ? "-" : "+"
        let magnitude = seconds < 0 ? -seconds : seconds
        let hours = magnitude / 3600
        let minutes = (magnitude % 3600) / 60
        // Matches Foundation's format, e.g. "GMT+0100" (no colon).
        return "GMT" + sign + twoDigits(hours) + twoDigits(minutes)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }

    private static func parseGMTOffset(_ identifier: String) -> Int? {
        var chars = Array(identifier.utf8)
        // Drop "GMT" prefix.
        chars.removeFirst(3)
        guard chars.isEmpty == false else { return 0 }

        let sign: Int
        switch chars[0] {
        case UInt8(ascii: "+"): sign = 1
        case UInt8(ascii: "-"): sign = -1
        default: return nil
        }
        chars.removeFirst()

        // Accept "HH:MM", "HHMM", or "HH".
        var digits: [Int] = []
        for byte in chars where byte != UInt8(ascii: ":") {
            guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else { return nil }
            digits.append(Int(byte - UInt8(ascii: "0")))
        }

        let hours: Int
        let minutes: Int
        switch digits.count {
        case 2:
            hours = digits[0] * 10 + digits[1]
            minutes = 0
        case 4:
            hours = digits[0] * 10 + digits[1]
            minutes = digits[2] * 10 + digits[3]
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

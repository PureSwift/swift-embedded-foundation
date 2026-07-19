//
//  Date.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Date` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.Date`.
//
//  Clock-dependent API (`init()`, `now`, `timeIntervalSinceNow`) is omitted:
//  there is no portable clock on bare metal. Consumers construct dates from
//  externally-sourced time intervals.
//

public typealias TimeInterval = Double

public struct Date: Sendable {

    /// Number of seconds relative to the reference date of Jan 1, 2001, 00:00:00 UTC.
    public var timeIntervalSinceReferenceDate: TimeInterval

    public init(timeIntervalSinceReferenceDate: TimeInterval) {
        self.timeIntervalSinceReferenceDate = timeIntervalSinceReferenceDate
    }
}

extension Date {

    /// The number of seconds from 1 January 1970 to the reference date, 1 January 2001.
    public static let timeIntervalBetween1970AndReferenceDate: TimeInterval = 978307200.0

    /// A date in the distant future, in terms of centuries.
    public static var distantFuture: Date {
        Date(timeIntervalSinceReferenceDate: 63113904000.0)
    }

    /// A date in the distant past, in terms of centuries.
    public static var distantPast: Date {
        Date(timeIntervalSinceReferenceDate: -63114076800.0)
    }

    public init(timeIntervalSince1970: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: timeIntervalSince1970 - Date.timeIntervalBetween1970AndReferenceDate)
    }

    /// Returns a `Date` initialized relative to another given date by a given number of seconds.
    public init(timeInterval: TimeInterval, since date: Date) {
        self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + timeInterval)
    }

    public var timeIntervalSince1970: TimeInterval {
        timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
    }

    public func timeIntervalSince(_ other: Date) -> TimeInterval {
        timeIntervalSinceReferenceDate - other.timeIntervalSinceReferenceDate
    }

    public func addingTimeInterval(_ interval: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate + interval)
    }

    public mutating func addTimeInterval(_ interval: TimeInterval) {
        timeIntervalSinceReferenceDate += interval
    }

    public static func + (lhs: Date, rhs: TimeInterval) -> Date {
        lhs.addingTimeInterval(rhs)
    }

    public static func - (lhs: Date, rhs: TimeInterval) -> Date {
        lhs.addingTimeInterval(-rhs)
    }

    public static func - (lhs: Date, rhs: Date) -> TimeInterval {
        lhs.timeIntervalSince(rhs)
    }

    public static func += (lhs: inout Date, rhs: TimeInterval) {
        lhs.addTimeInterval(rhs)
    }

    public static func -= (lhs: inout Date, rhs: TimeInterval) {
        lhs.addTimeInterval(-rhs)
    }
}

// MARK: - Equatable, Comparable, Hashable

extension Date: Equatable, Comparable, Hashable {

    public static func == (lhs: Date, rhs: Date) -> Bool {
        lhs.timeIntervalSinceReferenceDate == rhs.timeIntervalSinceReferenceDate
    }

    public static func < (lhs: Date, rhs: Date) -> Bool {
        lhs.timeIntervalSinceReferenceDate < rhs.timeIntervalSinceReferenceDate
    }

    /// Compare two `Date` values.
    public func compare(_ other: Date) -> ComparisonResult {
        if timeIntervalSinceReferenceDate < other.timeIntervalSinceReferenceDate {
            return .orderedAscending
        } else if timeIntervalSinceReferenceDate > other.timeIntervalSinceReferenceDate {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(timeIntervalSinceReferenceDate)
    }
}

// MARK: - Strideable

extension Date: Strideable {

    public typealias Stride = TimeInterval

    public func distance(to other: Date) -> TimeInterval {
        other.timeIntervalSinceReferenceDate - timeIntervalSinceReferenceDate
    }

    public func advanced(by n: TimeInterval) -> Date {
        self + n
    }
}

// MARK: - CustomStringConvertible

extension Date: CustomStringConvertible, CustomDebugStringConvertible {

    /// A string representation of the date in UTC, e.g. `2001-01-01 00:00:00 +0000`.
    /// The representation is useful for debugging only.
    public var description: String {
        guard self >= Date.distantPast, self <= Date.distantFuture else {
            return "<description unavailable>"
        }
        let secondsSince1970 = timeIntervalSinceReferenceDate + Date.timeIntervalBetween1970AndReferenceDate
        // Floor division so pre-epoch dates land on the correct day.
        let wholeSeconds = Int(secondsSince1970.rounded(.down))
        var days = wholeSeconds / 86400
        var secondsOfDay = wholeSeconds % 86400
        if secondsOfDay < 0 {
            secondsOfDay += 86400
            days -= 1
        }
        let civil = Calendar.civilFromDays(days)
        return Self.pad(civil.year, 4) + "-" + Self.pad(civil.month, 2) + "-" + Self.pad(civil.day, 2)
            + " " + Self.pad(secondsOfDay / 3600, 2)
            + ":" + Self.pad((secondsOfDay % 3600) / 60, 2)
            + ":" + Self.pad(secondsOfDay % 60, 2)
            + " +0000"
    }

    public var debugDescription: String {
        description
    }

    private static func pad(_ value: Int, _ width: Int) -> String {
        var string = "\(value)"
        while string.utf8.count < width {
            string = "0" + string
        }
        return string
    }
}

// MARK: - Codable

#if !hasFeature(Embedded)
extension Date: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        self.init(timeIntervalSinceReferenceDate: try container.decode(TimeInterval.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(timeIntervalSinceReferenceDate)
    }
}
#endif

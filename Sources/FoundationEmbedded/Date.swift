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

@frozen
public struct Date: Sendable {

    /// Number of seconds relative to the reference date of Jan 1, 2001, 00:00:00 UTC.
    public var timeIntervalSinceReferenceDate: TimeInterval

    @inlinable
    public init(timeIntervalSinceReferenceDate: TimeInterval) {
        self.timeIntervalSinceReferenceDate = timeIntervalSinceReferenceDate
    }
}

extension Date {

    /// The number of seconds from 1 January 1970 to the reference date, 1 January 2001.
    ///
    /// - Note: The inlinable members below spell this constant out as a literal
    ///   rather than reading it from here. Reading a `static let` from an
    ///   inlined body emits a global access — with a one-time-initialization
    ///   check on targets that need one — at every call site, where the literal
    ///   folds into the surrounding arithmetic.
    public static let timeIntervalBetween1970AndReferenceDate: TimeInterval = 978307200.0

    /// A date in the distant future, in terms of centuries.
    @inlinable
    public static var distantFuture: Date {
        Date(timeIntervalSinceReferenceDate: 63113904000.0)
    }

    /// A date in the distant past, in terms of centuries.
    @inlinable
    public static var distantPast: Date {
        Date(timeIntervalSinceReferenceDate: -63114076800.0)
    }

    @inlinable
    public init(timeIntervalSince1970: TimeInterval) {
        self.init(timeIntervalSinceReferenceDate: timeIntervalSince1970 - 978307200.0)
    }

    /// Returns a `Date` initialized relative to another given date by a given number of seconds.
    @inlinable
    public init(timeInterval: TimeInterval, since date: Date) {
        self.init(timeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate + timeInterval)
    }

    @inlinable
    public var timeIntervalSince1970: TimeInterval {
        timeIntervalSinceReferenceDate + 978307200.0
    }

    @inlinable
    public func timeIntervalSince(_ other: Date) -> TimeInterval {
        timeIntervalSinceReferenceDate - other.timeIntervalSinceReferenceDate
    }

    @inlinable
    public func addingTimeInterval(_ interval: TimeInterval) -> Date {
        Date(timeIntervalSinceReferenceDate: timeIntervalSinceReferenceDate + interval)
    }

    @inlinable
    public mutating func addTimeInterval(_ interval: TimeInterval) {
        timeIntervalSinceReferenceDate += interval
    }

    @inlinable
    public static func + (lhs: Date, rhs: TimeInterval) -> Date {
        lhs.addingTimeInterval(rhs)
    }

    @inlinable
    public static func - (lhs: Date, rhs: TimeInterval) -> Date {
        lhs.addingTimeInterval(-rhs)
    }

    @inlinable
    public static func - (lhs: Date, rhs: Date) -> TimeInterval {
        lhs.timeIntervalSince(rhs)
    }

    @inlinable
    public static func += (lhs: inout Date, rhs: TimeInterval) {
        lhs.addTimeInterval(rhs)
    }

    @inlinable
    public static func -= (lhs: inout Date, rhs: TimeInterval) {
        lhs.addTimeInterval(-rhs)
    }
}

// MARK: - Equatable, Comparable, Hashable

extension Date: Equatable, Comparable, Hashable {

    @inlinable
    public static func == (lhs: Date, rhs: Date) -> Bool {
        lhs.timeIntervalSinceReferenceDate == rhs.timeIntervalSinceReferenceDate
    }

    @inlinable
    public static func < (lhs: Date, rhs: Date) -> Bool {
        lhs.timeIntervalSinceReferenceDate < rhs.timeIntervalSinceReferenceDate
    }

    /// Compare two `Date` values.
    @inlinable
    public func compare(_ other: Date) -> ComparisonResult {
        if timeIntervalSinceReferenceDate < other.timeIntervalSinceReferenceDate {
            return .orderedAscending
        } else if timeIntervalSinceReferenceDate > other.timeIntervalSinceReferenceDate {
            return .orderedDescending
        } else {
            return .orderedSame
        }
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(timeIntervalSinceReferenceDate)
    }
}

// MARK: - Strideable

extension Date: Strideable {

    public typealias Stride = TimeInterval

    @inlinable
    public func distance(to other: Date) -> TimeInterval {
        other.timeIntervalSinceReferenceDate - timeIntervalSinceReferenceDate
    }

    @inlinable
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

        // "YYYY-MM-DD HH:MM:SS +0000" is 25 bytes for every in-range date.
        var utf8: [UInt8] = []
        utf8.reserveCapacity(25)
        ASCII.appendPadded(civil.year, width: 4, to: &utf8)
        utf8.append(UInt8(ascii: "-"))
        ASCII.appendPadded(civil.month, width: 2, to: &utf8)
        utf8.append(UInt8(ascii: "-"))
        ASCII.appendPadded(civil.day, width: 2, to: &utf8)
        utf8.append(UInt8(ascii: " "))
        ASCII.appendPadded(secondsOfDay / 3600, width: 2, to: &utf8)
        utf8.append(UInt8(ascii: ":"))
        ASCII.appendPadded((secondsOfDay % 3600) / 60, width: 2, to: &utf8)
        utf8.append(UInt8(ascii: ":"))
        ASCII.appendPadded(secondsOfDay % 60, width: 2, to: &utf8)
        utf8.append(contentsOf: " +0000".utf8)
        return String(decoding: utf8, as: UTF8.self)
    }

    public var debugDescription: String {
        description
    }
}

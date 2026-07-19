//
//  DateInterval.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `DateInterval` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.DateInterval`.
//
//  The clock-dependent no-argument initializer is omitted.
//

/// A closed date interval in the form of [start, end]. The start and end dates
/// may be the same, with a duration of 0. Reverse intervals (negative
/// durations) are not supported.
public struct DateInterval: Sendable {

    /// The start date.
    public var start: Date

    /// The end date.
    ///
    /// - Precondition: `end >= start`
    public var end: Date {
        get {
            start + duration
        }
        set {
            precondition(newValue >= start, "Reverse intervals are not allowed")
            duration = newValue.timeIntervalSinceReferenceDate - start.timeIntervalSinceReferenceDate
        }
    }

    /// The duration.
    ///
    /// - Precondition: `duration >= 0`
    public var duration: TimeInterval {
        willSet {
            precondition(newValue >= 0, "Negative durations are not allowed")
        }
    }

    /// Initialize a `DateInterval` with the specified start and end date.
    ///
    /// - Precondition: `end >= start`
    public init(start: Date, end: Date) {
        precondition(end >= start, "Reverse intervals are not allowed")
        self.start = start
        self.duration = end.timeIntervalSince(start)
    }

    /// Initialize a `DateInterval` with the specified start date and duration.
    ///
    /// - Precondition: `duration >= 0`
    public init(start: Date, duration: TimeInterval) {
        precondition(duration >= 0, "Negative durations are not allowed")
        self.start = start
        self.duration = duration
    }
}

extension DateInterval {

    /// Compares two intervals, ordering by start date and then by duration.
    public func compare(_ dateInterval: DateInterval) -> ComparisonResult {
        let result = start.compare(dateInterval.start)
        if result == .orderedSame {
            if duration < dateInterval.duration { return .orderedAscending }
            if duration > dateInterval.duration { return .orderedDescending }
            return .orderedSame
        }
        return result
    }

    /// Returns `true` if `self` contains `date`.
    public func contains(_ date: Date) -> Bool {
        date >= start && date <= end
    }

    /// Returns `true` if `self` intersects the `dateInterval`.
    public func intersects(_ dateInterval: DateInterval) -> Bool {
        contains(dateInterval.start) || contains(dateInterval.end)
            || dateInterval.contains(start) || dateInterval.contains(end)
    }

    /// Returns the interval where the given interval and the current instance
    /// intersect, or `nil` if they do not intersect.
    public func intersection(with dateInterval: DateInterval) -> DateInterval? {
        guard intersects(dateInterval) else {
            return nil
        }
        let resultStart = Swift.max(start, dateInterval.start)
        let resultEnd = Swift.min(end, dateInterval.end)
        return DateInterval(start: resultStart, end: resultEnd)
    }
}

// MARK: - Equatable, Comparable, Hashable

extension DateInterval: Equatable, Comparable, Hashable {

    public static func == (lhs: DateInterval, rhs: DateInterval) -> Bool {
        lhs.start == rhs.start && lhs.duration == rhs.duration
    }

    public static func < (lhs: DateInterval, rhs: DateInterval) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(start)
        hasher.combine(duration)
    }
}

// MARK: - CustomStringConvertible

extension DateInterval: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        "\(start) to \(end)"
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Codable

#if !hasFeature(Embedded)
extension DateInterval: Codable {

    private enum CodingKeys: String, CodingKey {
        case start
        case duration
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let start = try container.decode(Date.self, forKey: .start)
        let duration = try container.decode(TimeInterval.self, forKey: .duration)
        guard duration >= 0 else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Attempted to decode DateInterval with negative duration."))
        }
        self.init(start: start, duration: duration)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(start, forKey: .start)
        try container.encode(duration, forKey: .duration)
    }
}
#endif

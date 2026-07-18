//
//  DateComponents.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `DateComponents` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.DateComponents`.
//
//  A plain bag of optional calendar fields — no calendar arithmetic of its own.
//

public struct DateComponents: Sendable, Hashable {

    public var era: Int?
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var hour: Int?
    public var minute: Int?
    public var second: Int?
    public var nanosecond: Int?

    /// Day of the week, `1 == Sunday` through `7 == Saturday` (Gregorian).
    public var weekday: Int?

    public var timeZone: TimeZone?

    public init(
        era: Int? = nil,
        year: Int? = nil,
        month: Int? = nil,
        day: Int? = nil,
        hour: Int? = nil,
        minute: Int? = nil,
        second: Int? = nil,
        nanosecond: Int? = nil,
        weekday: Int? = nil,
        timeZone: TimeZone? = nil
    ) {
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond
        self.weekday = weekday
        self.timeZone = timeZone
    }
}

// MARK: - CustomStringConvertible

extension DateComponents: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        var parts: [String] = []
        func append(_ label: String, _ value: Int?) {
            if let value {
                parts.append("\(label): \(value)")
            }
        }
        append("era", era)
        append("year", year)
        append("month", month)
        append("day", day)
        append("hour", hour)
        append("minute", minute)
        append("second", second)
        append("nanosecond", nanosecond)
        append("weekday", weekday)
        if let timeZone {
            parts.append("timeZone: \(timeZone.identifier)")
        }
        return "DateComponents(" + parts.joined(separator: ", ") + ")"
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Codable

#if !hasFeature(Embedded)
extension DateComponents: Codable {

    private enum CodingKeys: String, CodingKey {
        case era, year, month, day, hour, minute, second, nanosecond, weekday, timeZone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            era: try container.decodeIfPresent(Int.self, forKey: .era),
            year: try container.decodeIfPresent(Int.self, forKey: .year),
            month: try container.decodeIfPresent(Int.self, forKey: .month),
            day: try container.decodeIfPresent(Int.self, forKey: .day),
            hour: try container.decodeIfPresent(Int.self, forKey: .hour),
            minute: try container.decodeIfPresent(Int.self, forKey: .minute),
            second: try container.decodeIfPresent(Int.self, forKey: .second),
            nanosecond: try container.decodeIfPresent(Int.self, forKey: .nanosecond),
            weekday: try container.decodeIfPresent(Int.self, forKey: .weekday),
            timeZone: try container.decodeIfPresent(TimeZone.self, forKey: .timeZone))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(era, forKey: .era)
        try container.encodeIfPresent(year, forKey: .year)
        try container.encodeIfPresent(month, forKey: .month)
        try container.encodeIfPresent(day, forKey: .day)
        try container.encodeIfPresent(hour, forKey: .hour)
        try container.encodeIfPresent(minute, forKey: .minute)
        try container.encodeIfPresent(second, forKey: .second)
        try container.encodeIfPresent(nanosecond, forKey: .nanosecond)
        try container.encodeIfPresent(weekday, forKey: .weekday)
        try container.encodeIfPresent(timeZone, forKey: .timeZone)
    }
}
#endif

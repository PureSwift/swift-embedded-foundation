//
//  DateComponents.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `DateComponents` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.DateComponents`.
//
//  A plain bag of optional calendar fields — no calendar arithmetic of its own.
//  The week fields, the day of the year and the leap month are filled in by
//  a platform's calendar (the `PlatformHooks` trait); the package's own
//  Gregorian arithmetic leaves them empty.
//

@frozen
public struct DateComponents: Sendable, Hashable {

    /// The calendar the components are in, for `date`.
    public var calendar: Calendar?

    public var era: Int?
    public var year: Int?
    public var month: Int?
    public var day: Int?
    public var hour: Int?
    public var minute: Int?
    public var second: Int?
    public var nanosecond: Int?

    /// Day of the week, `1 == Sunday` through `7 == Saturday`.
    public var weekday: Int?

    /// Which of that weekday in its month: the second Tuesday is 2.
    public var weekdayOrdinal: Int?

    public var weekOfMonth: Int?
    public var weekOfYear: Int?

    /// The year the week of the year belongs to, which at a year's ends
    /// isn't always the calendar year.
    public var yearForWeekOfYear: Int?

    public var dayOfYear: Int?

    /// Whether the month is a leap month, in calendars that have them.
    public var isLeapMonth: Bool?

    public var timeZone: TimeZone?

    @inlinable
    public init(
        calendar: Calendar? = nil,
        era: Int? = nil,
        year: Int? = nil,
        month: Int? = nil,
        day: Int? = nil,
        hour: Int? = nil,
        minute: Int? = nil,
        second: Int? = nil,
        nanosecond: Int? = nil,
        weekday: Int? = nil,
        weekdayOrdinal: Int? = nil,
        weekOfMonth: Int? = nil,
        weekOfYear: Int? = nil,
        yearForWeekOfYear: Int? = nil,
        timeZone: TimeZone? = nil
    ) {
        self.calendar = calendar
        self.era = era
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
        self.second = second
        self.nanosecond = nanosecond
        self.weekday = weekday
        self.weekdayOrdinal = weekdayOrdinal
        self.weekOfMonth = weekOfMonth
        self.weekOfYear = weekOfYear
        self.yearForWeekOfYear = yearForWeekOfYear
        self.timeZone = timeZone
    }
}

extension DateComponents {

    /// The date the components name in their `calendar`; `nil` without one,
    /// or if there is no such date.
    public var date: Date? {
        calendar?.date(from: self)
    }

    /// The value of one component; `nil` if it isn't set.
    public func value(for component: Calendar.Component) -> Int? {
        switch component {
        case .era: return era
        case .year: return year
        case .month: return month
        case .day: return day
        case .hour: return hour
        case .minute: return minute
        case .second: return second
        case .nanosecond: return nanosecond
        case .weekday: return weekday
        case .weekdayOrdinal: return weekdayOrdinal
        case .weekOfMonth: return weekOfMonth
        case .weekOfYear: return weekOfYear
        case .yearForWeekOfYear: return yearForWeekOfYear
        case .dayOfYear: return dayOfYear
        }
    }

    /// Sets one component.
    public mutating func setValue(_ value: Int?, for component: Calendar.Component) {
        switch component {
        case .era: era = value
        case .year: year = value
        case .month: month = value
        case .day: day = value
        case .hour: hour = value
        case .minute: minute = value
        case .second: second = value
        case .nanosecond: nanosecond = value
        case .weekday: weekday = value
        case .weekdayOrdinal: weekdayOrdinal = value
        case .weekOfMonth: weekOfMonth = value
        case .weekOfYear: weekOfYear = value
        case .yearForWeekOfYear: yearForWeekOfYear = value
        case .dayOfYear: dayOfYear = value
        }
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
        append("weekdayOrdinal", weekdayOrdinal)
        append("weekOfMonth", weekOfMonth)
        append("weekOfYear", weekOfYear)
        append("yearForWeekOfYear", yearForWeekOfYear)
        append("dayOfYear", dayOfYear)
        if let isLeapMonth {
            parts.append("isLeapMonth: \(isLeapMonth)")
        }
        if let timeZone {
            parts.append("timeZone: \(timeZone.identifier)")
        }
        return "DateComponents(" + parts.joined(separator: ", ") + ")"
    }

    public var debugDescription: String {
        description
    }
}

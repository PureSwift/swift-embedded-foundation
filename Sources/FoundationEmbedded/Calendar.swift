//
//  Calendar.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Calendar` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.Calendar`.
//
//  Gregorian calendar only. The proleptic Gregorian date <-> time-interval
//  math is Foundation-free. Compiles on any platform, using this module's own
//  `Date`; the consumer decides when to use it in place of `Foundation.Calendar`.
//

public struct Calendar: Sendable, Hashable {

    public enum Identifier: Sendable, Hashable {
        case gregorian
    }

    public enum Component: Sendable, Hashable {
        case era, year, month, day, hour, minute, second, nanosecond, weekday
    }

    public let identifier: Identifier
    public var timeZone: TimeZone
    public var locale: Locale?

    /// - Precondition: `identifier` must be `.gregorian`; it is the only
    ///   calendar this shim implements.
    public init(identifier: Identifier) {
        precondition(identifier == .gregorian, "FoundationEmbedded.Calendar only supports the Gregorian calendar")
        self.identifier = identifier
        self.timeZone = .gmt
        self.locale = .current
    }

    /// The current calendar (always Gregorian, in GMT).
    public static var current: Calendar {
        Calendar(identifier: .gregorian)
    }
}

// MARK: - Gregorian Math (Foundation-free)

extension Calendar {

    /// Seconds between the Unix epoch (Jan 1, 1970) and the reference date (Jan 1, 2001).
    static var referenceDateToUnixEpoch: Double { 978307200.0 }

    /// Days from the Unix epoch (1970-01-01) to the given proleptic Gregorian date.
    ///
    /// Based on Howard Hinnant's `days_from_civil`.
    static func daysFromCivil(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yearOfEra = y - era * 400                                   // [0, 399]
        let monthTerm = month > 2 ? month - 3 : month + 9
        let dayOfYear = (153 * monthTerm + 2) / 5 + day - 1            // [0, 365]
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146097 + dayOfEra - 719468
    }

    /// The proleptic Gregorian date for the given day count from the Unix epoch.
    ///
    /// Based on Howard Hinnant's `civil_from_days`.
    static func civilFromDays(_ days: Int) -> (year: Int, month: Int, day: Int) {
        let z = days + 719468
        let era = (z >= 0 ? z : z - 146096) / 146097
        let dayOfEra = z - era * 146097                                // [0, 146096]
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36524 - dayOfEra / 146096) / 365
        let year = yearOfEra + era * 400
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let monthPortion = (5 * dayOfYear + 2) / 153                   // [0, 11]
        let day = dayOfYear - (153 * monthPortion + 2) / 5 + 1         // [1, 31]
        let month = monthPortion < 10 ? monthPortion + 3 : monthPortion - 9
        return (month <= 2 ? year + 1 : year, month, day)
    }

    /// Weekday for a day count from the Unix epoch, `1 == Sunday` (Gregorian).
    static func weekday(fromDaysSinceEpoch days: Int) -> Int {
        // 1970-01-01 was a Thursday (Sunday-based weekday 5).
        (((days % 7) + 7) % 7 + 4) % 7 + 1
    }

    /// Whether the given proleptic Gregorian year is a leap year.
    static func isLeapYear(_ year: Int) -> Bool {
        year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
    }

    /// Number of days in the given month of the given proleptic Gregorian year.
    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 1, 3, 5, 7, 8, 10, 12: return 31
        case 4, 6, 9, 11: return 30
        case 2: return isLeapYear(year) ? 29 : 28
        default: return 0
        }
    }

    /// Floor division (rounds toward negative infinity).
    static func floorDivide(_ value: Int, _ divisor: Int) -> Int {
        let quotient = value / divisor
        return (value % divisor != 0 && (value ^ divisor) < 0) ? quotient - 1 : quotient
    }

    /// Convert `DateComponents` to a time interval since the reference date.
    ///
    /// Returns `nil` if year, month, or day are missing. Uses the components'
    /// `timeZone` if present, otherwise the calendar's `timeZone`.
    func timeIntervalSinceReferenceDate(from components: DateComponents) -> Double? {
        guard let year = components.year,
            let month = components.month,
            let day = components.day
        else {
            return nil
        }
        let days = Calendar.daysFromCivil(year: year, month: month, day: day)
        let secondsOfDay = (components.hour ?? 0) * 3600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0)
        let offset = (components.timeZone ?? timeZone).secondsFromGMT
        let secondsSince1970 = Double(days * 86400 + secondsOfDay - offset)
        let nanoseconds = Double(components.nanosecond ?? 0) / 1_000_000_000
        return secondsSince1970 + nanoseconds - Calendar.referenceDateToUnixEpoch
    }

    /// Decompose a time interval since the reference date into `DateComponents`.
    func dateComponents(fromTimeIntervalSinceReferenceDate interval: Double) -> DateComponents {
        let secondsSince1970 = interval + Calendar.referenceDateToUnixEpoch + Double(timeZone.secondsFromGMT)
        // Floor division so negative intervals land on the correct day.
        let wholeSeconds = Int(secondsSince1970.rounded(.down))
        var days = wholeSeconds / 86400
        var secondsOfDay = wholeSeconds % 86400
        if secondsOfDay < 0 {
            secondsOfDay += 86400
            days -= 1
        }
        let civil = Calendar.civilFromDays(days)
        return DateComponents(
            era: 1,
            year: civil.year,
            month: civil.month,
            day: civil.day,
            hour: secondsOfDay / 3600,
            minute: (secondsOfDay % 3600) / 60,
            second: secondsOfDay % 60,
            weekday: Calendar.weekday(fromDaysSinceEpoch: days),
            timeZone: timeZone)
    }
}

// MARK: - Date Bridging

extension Calendar {

    /// Convert `DateComponents` into a `Date`, or `nil` if year/month/day are missing.
    public func date(from components: DateComponents) -> Date? {
        guard let interval = timeIntervalSinceReferenceDate(from: components) else {
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// Decompose a `Date` into its Gregorian components.
    ///
    /// - Note: `components` is accepted for source compatibility with
    ///   Foundation; this shim always populates every supported field.
    public func dateComponents(_ components: Set<Component>, from date: Date) -> DateComponents {
        dateComponents(fromTimeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
    }

    /// The value of a single Gregorian component of `date`.
    public func component(_ component: Component, from date: Date) -> Int {
        let all = dateComponents(fromTimeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
        switch component {
        case .era: return all.era ?? 1
        case .year: return all.year ?? 0
        case .month: return all.month ?? 0
        case .day: return all.day ?? 0
        case .hour: return all.hour ?? 0
        case .minute: return all.minute ?? 0
        case .second: return all.second ?? 0
        case .nanosecond: return all.nanosecond ?? 0
        case .weekday: return all.weekday ?? 0
        }
    }
}

// MARK: - Calendrical Calculations

extension Calendar {

    /// The first moment of the given date's day, in the calendar's time zone.
    public func startOfDay(for date: Date) -> Date {
        let offset = Double(timeZone.secondsFromGMT)
        let secondsSince1970 = date.timeIntervalSinceReferenceDate + Calendar.referenceDateToUnixEpoch + offset
        let days = (secondsSince1970 / 86400).rounded(.down)
        return Date(timeIntervalSinceReferenceDate: days * 86400 - offset - Calendar.referenceDateToUnixEpoch)
    }

    /// Whether two dates fall on the same day in the calendar's time zone.
    public func isDate(_ date1: Date, inSameDayAs date2: Date) -> Bool {
        startOfDay(for: date1) == startOfDay(for: date2)
    }

    /// Returns a date created by adding components to a given date.
    ///
    /// Year and month arithmetic clamps the day of month to the length of the
    /// target month (e.g. Jan 31 plus one month is Feb 28 or 29).
    ///
    /// - Note: Only non-wrapping arithmetic is implemented.
    public func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date? {
        precondition(wrappingComponents == false, "FoundationEmbedded.Calendar does not implement wrapping arithmetic")

        var interval = date.timeIntervalSinceReferenceDate

        // Year and month arithmetic operates on the civil date, applied
        // sequentially (year first, then month), clamping the day of month
        // after each step — e.g. Feb 29 minus one year is Feb 28, and a
        // subsequent month subtraction starts from the 28th.
        if components.year != nil || components.month != nil {
            let offset = Double(timeZone.secondsFromGMT)
            let secondsSince1970 = interval + Calendar.referenceDateToUnixEpoch + offset
            let days = Int((secondsSince1970 / 86400).rounded(.down))
            let secondsOfDay = secondsSince1970 - Double(days) * 86400
            var civil = Calendar.civilFromDays(days)

            if let years = components.year, years != 0 {
                let year = civil.year + years
                civil = (year, civil.month, Swift.min(civil.day, Calendar.daysInMonth(year: year, month: civil.month)))
            }
            if let deltaMonths = components.month, deltaMonths != 0 {
                let monthIndex = civil.year * 12 + (civil.month - 1) + deltaMonths
                let year = Calendar.floorDivide(monthIndex, 12)
                let month = monthIndex - year * 12 + 1
                civil = (year, month, Swift.min(civil.day, Calendar.daysInMonth(year: year, month: month)))
            }

            let newDays = Calendar.daysFromCivil(year: civil.year, month: civil.month, day: civil.day)
            interval = Double(newDays) * 86400 + secondsOfDay - offset - Calendar.referenceDateToUnixEpoch
        }

        // Day and time arithmetic is absolute (fixed-offset zone, no DST).
        interval += Double((components.day ?? 0) * 86400
            + (components.hour ?? 0) * 3600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0))
        interval += Double(components.nanosecond ?? 0) / 1_000_000_000

        return Date(timeIntervalSinceReferenceDate: interval)
    }

    /// Returns a date created by adding a value of a single component to a given date.
    public func date(byAdding component: Component, value: Int, to date: Date, wrappingComponents: Bool = false) -> Date? {
        var components = DateComponents()
        switch component {
        case .era, .weekday:
            return nil
        case .year: components.year = value
        case .month: components.month = value
        case .day: components.day = value
        case .hour: components.hour = value
        case .minute: components.minute = value
        case .second: components.second = value
        case .nanosecond: components.nanosecond = value
        }
        return self.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    /// The range of absolute values a smaller component can take in a larger
    /// component that includes the given date.
    ///
    /// Supports `.day` in `.month`, `.day` in `.year`, and `.month` in `.year`;
    /// returns `nil` for other combinations.
    public func range(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        let components = dateComponents(fromTimeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
        guard let year = components.year, let month = components.month else {
            return nil
        }
        switch (smaller, larger) {
        case (.day, .month):
            return 1..<(Calendar.daysInMonth(year: year, month: month) + 1)
        case (.day, .year):
            return 1..<(Calendar.isLeapYear(year) ? 367 : 366)
        case (.month, .year):
            return 1..<13
        default:
            return nil
        }
    }
}

// MARK: - Codable

#if !hasFeature(Embedded)
extension Calendar: Codable {

    private enum CodingKeys: String, CodingKey {
        case timeZone
        case locale
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(identifier: .gregorian)
        self.timeZone = try container.decode(TimeZone.self, forKey: .timeZone)
        self.locale = try container.decodeIfPresent(Locale.self, forKey: .locale)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeZone, forKey: .timeZone)
        try container.encodeIfPresent(locale, forKey: .locale)
    }
}
#endif

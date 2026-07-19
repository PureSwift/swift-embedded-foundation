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

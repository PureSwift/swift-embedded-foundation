//
//  Calendar.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Calendar` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.Calendar`.
//
//  By itself the package has the Gregorian calendar: the proleptic
//  Gregorian date <-> time-interval math is Foundation-free, in a
//  fixed-offset zone or in the process's own. Built with the
//  `PlatformHooks` trait, every public operation is the platform's
//  (`FoundationEmbeddedPlatform.h`), in any calendar and any zone, and the
//  package's own code keeps to the math below.
//

public struct Calendar: Sendable, Hashable {

    public enum Identifier: Sendable, Hashable {
        case gregorian
        #if PlatformHooks
        case buddhist
        case chinese
        case coptic
        case ethiopicAmeteMihret
        case ethiopicAmeteAlem
        case hebrew
        case iso8601
        case indian
        case islamic
        case islamicCivil
        case japanese
        case persian
        case republicOfChina
        case islamicTabular
        case islamicUmmAlQura
        #endif
    }

    public enum Component: Sendable, Hashable {
        case era, year, month, day, hour, minute, second, nanosecond, weekday
        case weekdayOrdinal, weekOfMonth, weekOfYear, yearForWeekOfYear, dayOfYear
    }

    public let identifier: Identifier
    public var timeZone: TimeZone
    public var locale: Locale?

    /// 1...7 once set; 0 for the locale's.
    @usableFromInline
    var storedFirstWeekday: Int

    /// 1...7 once set; 0 for the locale's.
    @usableFromInline
    var storedMinimumDays: Int

    /// A calendar in the current time zone and locale, as in Foundation.
    public init(identifier: Identifier) {
        self.identifier = identifier
        self.timeZone = .current
        self.locale = .current
        self.storedFirstWeekday = 0
        self.storedMinimumDays = 0
    }

    /// The Gregorian calendar in GMT, which needs nothing of a platform.
    /// What the package's own formats count in.
    init(gregorianIn timeZone: TimeZone) {
        self.identifier = .gregorian
        self.timeZone = timeZone
        self.locale = nil
        self.storedFirstWeekday = 0
        self.storedMinimumDays = 0
    }

    /// The current calendar.
    ///
    /// With the `PlatformHooks` trait, the user's calendar as the platform
    /// has it. Without it, the Gregorian calendar. Either way it is in
    /// `TimeZone.current` and `Locale.current`.
    public static var current: Calendar {
        #if PlatformHooks
        return Platform.currentCalendar()
        #else
        return Calendar(identifier: .gregorian)
        #endif
    }

    /// The first day of the week: 1 is Sunday. The locale's until it is
    /// set, which without the `PlatformHooks` trait is Sunday.
    public var firstWeekday: Int {
        get {
            if storedFirstWeekday != 0 {
                return storedFirstWeekday
            }
            #if PlatformHooks
            return Platform.firstWeekday(of: self)
            #else
            return 1
            #endif
        }
        set {
            storedFirstWeekday = newValue
        }
    }

    /// How many days of a year its first week must have. The locale's until
    /// it is set, which without the `PlatformHooks` trait is 1.
    public var minimumDaysInFirstWeek: Int {
        get {
            if storedMinimumDays != 0 {
                return storedMinimumDays
            }
            #if PlatformHooks
            return Platform.minimumDays(of: self)
            #else
            return 1
            #endif
        }
        set {
            storedMinimumDays = newValue
        }
    }
}

#if PlatformHooks

extension Calendar.Identifier {

    /// The calendar's Unicode name, as the platform's header carries it.
    var name: String {
        switch self {
        case .gregorian: return "gregorian"
        case .buddhist: return "buddhist"
        case .chinese: return "chinese"
        case .coptic: return "coptic"
        case .ethiopicAmeteMihret: return "ethiopic"
        case .ethiopicAmeteAlem: return "ethioaa"
        case .hebrew: return "hebrew"
        case .iso8601: return "iso8601"
        case .indian: return "indian"
        case .islamic: return "islamic"
        case .islamicCivil: return "islamic-civil"
        case .japanese: return "japanese"
        case .persian: return "persian"
        case .republicOfChina: return "roc"
        case .islamicTabular: return "islamic-tbla"
        case .islamicUmmAlQura: return "islamic-umalqura"
        }
    }

    static let all: [Calendar.Identifier] = [
        .gregorian, .buddhist, .chinese, .coptic, .ethiopicAmeteMihret, .ethiopicAmeteAlem, .hebrew, .iso8601,
        .indian, .islamic, .islamicCivil, .japanese, .persian, .republicOfChina, .islamicTabular, .islamicUmmAlQura,
    ]

    init?(name: String) {
        guard let identifier = Calendar.Identifier.all.first(where: { $0.name == name }) else {
            return nil
        }
        self = identifier
    }
}

#endif

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

    // MARK: Zones

    /// The moment a wall-clock time names in a zone, both in seconds since
    /// 1970.
    ///
    /// A fixed offset is subtracted. For a zone whose offset changes, a time
    /// that doesn't exist (the clocks went forward over it) is moved later
    /// by the gap, and one that happens twice (they went back) is the
    /// first, as Foundation has them.
    static func moment(ofLocal local: Double, in zone: TimeZone) -> Double {
        if zone.kind == .fixed {
            return local - Double(zone.secondsFromGMT)
        }
        // The offsets a day either side of it, which a change of clocks
        // falls between.
        let before = Double(zone.secondsFromGMT(for: Date(timeIntervalSince1970: local - 86400)))
        let after = Double(zone.secondsFromGMT(for: Date(timeIntervalSince1970: local + 86400)))
        let first = local - before
        if before == after {
            return first
        }
        let second = local - after
        let firstHolds = Double(zone.secondsFromGMT(for: Date(timeIntervalSince1970: first))) == before
        let secondHolds = Double(zone.secondsFromGMT(for: Date(timeIntervalSince1970: second))) == after
        switch (firstHolds, secondHolds) {
        case (true, true): return Swift.min(first, second)
        case (true, false): return first
        case (false, true): return second
        case (false, false): return Swift.max(first, second)
        }
    }

    /// A moment as the zone's clocks show it: seconds since 1970 with the
    /// zone's offset at that moment added.
    func local(_ secondsSince1970: Double) -> Double {
        secondsSince1970 + Double(timeZone.secondsFromGMT(for: Date(timeIntervalSince1970: secondsSince1970)))
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
        let local = Double(days * 86400 + secondsOfDay)
        let secondsSince1970 = Calendar.moment(ofLocal: local, in: components.timeZone ?? timeZone)
        let nanoseconds = Double(components.nanosecond ?? 0) / 1_000_000_000
        return secondsSince1970 + nanoseconds - Calendar.referenceDateToUnixEpoch
    }

    /// Decompose a time interval since the reference date into `DateComponents`.
    func dateComponents(fromTimeIntervalSinceReferenceDate interval: Double) -> DateComponents {
        let secondsSince1970 = local(interval + Calendar.referenceDateToUnixEpoch)
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

    // MARK: The package's own arithmetic

    func gregorianDate(from components: DateComponents) -> Date? {
        guard let interval = timeIntervalSinceReferenceDate(from: components) else {
            return nil
        }
        return Date(timeIntervalSinceReferenceDate: interval)
    }

    func gregorianComponents(from date: Date) -> DateComponents {
        dateComponents(fromTimeIntervalSinceReferenceDate: date.timeIntervalSinceReferenceDate)
    }

    func gregorianStartOfDay(for date: Date) -> Date {
        let days = (local(date.timeIntervalSince1970) / 86400).rounded(.down)
        return Date(timeIntervalSince1970: Calendar.moment(ofLocal: days * 86400, in: timeZone))
    }

    /// Year and month arithmetic clamps the day of month to the length of
    /// the target month. Years, months and days keep the time on the zone's
    /// clocks; hours, minutes and seconds add that much time.
    func gregorianDate(byAdding components: DateComponents, to date: Date) -> Date {
        var interval = date.timeIntervalSince1970

        let years = components.year ?? 0
        let months = components.month ?? 0
        let addedDays = components.day ?? 0
        if years != 0 || months != 0 || addedDays != 0 {
            let localSeconds = local(interval)
            let days = Int((localSeconds / 86400).rounded(.down))
            let secondsOfDay = localSeconds - Double(days) * 86400
            var civil = Calendar.civilFromDays(days)

            // Applied in turn (year first, then month), clamping the day of
            // month after each step — e.g. Feb 29 minus one year is Feb 28,
            // and a subsequent month subtraction starts from the 28th.
            if years != 0 {
                let year = civil.year + years
                civil = (year, civil.month, Swift.min(civil.day, Calendar.daysInMonth(year: year, month: civil.month)))
            }
            if months != 0 {
                let monthIndex = civil.year * 12 + (civil.month - 1) + months
                let year = Calendar.floorDivide(monthIndex, 12)
                let month = monthIndex - year * 12 + 1
                civil = (year, month, Swift.min(civil.day, Calendar.daysInMonth(year: year, month: month)))
            }

            let newDays = Calendar.daysFromCivil(year: civil.year, month: civil.month, day: civil.day) + addedDays
            interval = Calendar.moment(ofLocal: Double(newDays) * 86400 + secondsOfDay, in: timeZone)
        }

        interval += Double((components.hour ?? 0) * 3600
            + (components.minute ?? 0) * 60
            + (components.second ?? 0))
        interval += Double(components.nanosecond ?? 0) / 1_000_000_000

        return Date(timeIntervalSince1970: interval)
    }

    func gregorianRange(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        let components = gregorianComponents(from: date)
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

// MARK: - Date Bridging

extension Calendar {

    /// Convert `DateComponents` into a `Date`, or `nil` if there is no such
    /// date. The package's own arithmetic needs the year, month and day.
    public func date(from components: DateComponents) -> Date? {
        #if PlatformHooks
        var calendar = self
        if let zone = components.timeZone {
            calendar.timeZone = zone
        }
        return Platform.date(from: components.fields, in: calendar)
        #else
        return gregorianDate(from: components)
        #endif
    }

    /// Decompose a `Date` into its components.
    ///
    /// - Note: The package's own arithmetic populates every field it
    ///   supports, whatever is asked for. A platform's gives the ones asked
    ///   for, as Foundation does.
    public func dateComponents(_ components: Set<Component>, from date: Date) -> DateComponents {
        #if PlatformHooks
        guard let fields = Platform.fields(of: date, in: self) else {
            return DateComponents()
        }
        return DateComponents(fields: fields, only: components)
        #else
        return gregorianComponents(from: date)
        #endif
    }

    /// The value of a single component of `date`.
    public func component(_ component: Component, from date: Date) -> Int {
        #if PlatformHooks
        guard let fields = Platform.fields(of: date, in: self) else {
            return 0
        }
        let value = fields[Int(component.unit)]
        return value == Platform.none ? 0 : value
        #else
        let all = gregorianComponents(from: date)
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
        case .weekdayOrdinal, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear: return 0
        }
        #endif
    }
}

// MARK: - Calendrical Calculations

extension Calendar {

    /// The first moment of the given date's day, in the calendar's time zone.
    public func startOfDay(for date: Date) -> Date {
        #if PlatformHooks
        return Platform.start(of: Component.day.unit, containing: date, in: self) ?? date
        #else
        return gregorianStartOfDay(for: date)
        #endif
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
    /// - Note: The package's own arithmetic implements only non-wrapping
    ///   arithmetic. A platform's does both.
    public func date(byAdding components: DateComponents, to date: Date, wrappingComponents: Bool = false) -> Date? {
        #if PlatformHooks
        return Platform.adding(components.fields, to: date, wrapping: wrappingComponents, in: self)
        #else
        precondition(wrappingComponents == false, "FoundationEmbedded.Calendar does not implement wrapping arithmetic")
        return gregorianDate(byAdding: components, to: date)
        #endif
    }

    /// Returns a date created by adding a value of a single component to a given date.
    public func date(byAdding component: Component, value: Int, to date: Date, wrappingComponents: Bool = false) -> Date? {
        var components = DateComponents()
        switch component {
        case .era, .weekday:
            return nil
        default:
            components.setValue(value, for: component)
        }
        #if !PlatformHooks
        switch component {
        case .weekdayOrdinal, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear:
            return nil
        default:
            break
        }
        #endif
        return self.date(byAdding: components, to: date, wrappingComponents: wrappingComponents)
    }

    /// The range of absolute values a smaller component can take in a larger
    /// component that includes the given date.
    ///
    /// The package's own arithmetic supports `.day` in `.month`, `.day` in
    /// `.year`, and `.month` in `.year`, and returns `nil` for other
    /// combinations.
    public func range(of smaller: Component, in larger: Component, for date: Date) -> Range<Int>? {
        #if PlatformHooks
        return Platform.range(of: smaller.unit, in: larger.unit, for: date, in: self)
        #else
        return gregorianRange(of: smaller, in: larger, for: date)
        #endif
    }
}

#if PlatformHooks

// MARK: - From the platform

extension Calendar {

    /// Foundation's `Calendar.MatchingPolicy`.
    public enum MatchingPolicy: Sendable, Hashable {
        /// If the time doesn't exist that day, the next that does.
        case nextTime
        /// The same, keeping the smaller components.
        case nextTimePreservingSmallerComponents
        /// The same, going back.
        case previousTimePreservingSmallerComponents
        /// Only a moment with exactly these components.
        case strict

        var number: Int32 {
            switch self {
            case .nextTime: return 0
            case .nextTimePreservingSmallerComponents: return 1
            case .previousTimePreservingSmallerComponents: return 2
            case .strict: return 3
            }
        }
    }

    /// Foundation's `Calendar.SearchDirection`.
    public enum SearchDirection: Sendable, Hashable {
        case forward
        case backward
    }

    /// The difference between two dates, in the components asked for.
    public func dateComponents(_ components: Set<Component>, from start: Date, to end: Date) -> DateComponents {
        guard let fields = Platform.difference(components.units, from: start, to: end, in: self) else {
            return DateComponents()
        }
        return DateComponents(fields: fields, only: components)
    }

    /// Where the component that holds a date starts and ends: its day, its
    /// week, its month.
    public func dateInterval(of component: Component, for date: Date) -> DateInterval? {
        guard let start = Platform.start(of: component.unit, containing: date, in: self),
              let end = Platform.end(of: component.unit, containing: date, in: self),
              end >= start else {
            return nil
        }
        return DateInterval(start: start, end: end)
    }

    /// Which one of the smaller component a date is in, within the larger:
    /// the day of the year.
    public func ordinality(of smaller: Component, in larger: Component, for date: Date) -> Int? {
        Platform.ordinality(of: smaller.unit, in: larger.unit, for: date, in: self)
    }

    /// The nearest date after one, or before it, that has the components
    /// given.
    public func nextDate(
        after date: Date,
        matching components: DateComponents,
        matchingPolicy: MatchingPolicy,
        direction: SearchDirection = .forward
    ) -> Date? {
        Platform.nextDate(
            after: date, matching: components.fields, policy: matchingPolicy.number,
            backward: direction == .backward, in: self)
    }

    public func isDateInWeekend(_ date: Date) -> Bool {
        Platform.isWeekend(date, in: self)
    }

    public func isDateInToday(_ date: Date) -> Bool {
        isDate(date, inSameDayAs: Platform.now())
    }

    public func isDateInYesterday(_ date: Date) -> Bool {
        guard let yesterday = self.date(byAdding: .day, value: -1, to: Platform.now()) else {
            return false
        }
        return isDate(date, inSameDayAs: yesterday)
    }

    public func isDateInTomorrow(_ date: Date) -> Bool {
        guard let tomorrow = self.date(byAdding: .day, value: 1, to: Platform.now()) else {
            return false
        }
        return isDate(date, inSameDayAs: tomorrow)
    }

    /// Compares two dates down to a component: their days, their months.
    public func compare(_ date1: Date, to date2: Date, toGranularity component: Component) -> ComparisonResult {
        guard let start1 = Platform.start(of: component.unit, containing: date1, in: self),
              let start2 = Platform.start(of: component.unit, containing: date2, in: self) else {
            return date1.compare(date2)
        }
        return start1.compare(start2)
    }

    public func isDate(_ date1: Date, equalTo date2: Date, toGranularity component: Component) -> Bool {
        compare(date1, to: date2, toGranularity: component) == .orderedSame
    }

    // The names, in the calendar's locale. Weekdays start at Sunday.

    public var monthSymbols: [String] { Platform.symbols(0, in: self) }
    public var shortMonthSymbols: [String] { Platform.symbols(1, in: self) }
    public var veryShortMonthSymbols: [String] { Platform.symbols(2, in: self) }
    public var standaloneMonthSymbols: [String] { Platform.symbols(3, in: self) }
    public var shortStandaloneMonthSymbols: [String] { Platform.symbols(4, in: self) }
    public var veryShortStandaloneMonthSymbols: [String] { Platform.symbols(5, in: self) }
    public var weekdaySymbols: [String] { Platform.symbols(6, in: self) }
    public var shortWeekdaySymbols: [String] { Platform.symbols(7, in: self) }
    public var veryShortWeekdaySymbols: [String] { Platform.symbols(8, in: self) }
    public var standaloneWeekdaySymbols: [String] { Platform.symbols(9, in: self) }
    public var shortStandaloneWeekdaySymbols: [String] { Platform.symbols(10, in: self) }
    public var veryShortStandaloneWeekdaySymbols: [String] { Platform.symbols(11, in: self) }
    public var eraSymbols: [String] { Platform.symbols(12, in: self) }
    public var longEraSymbols: [String] { Platform.symbols(13, in: self) }

    public var amSymbol: String {
        let symbols = Platform.symbols(14, in: self)
        return symbols.count == 2 ? symbols[0] : "AM"
    }

    public var pmSymbol: String {
        let symbols = Platform.symbols(14, in: self)
        return symbols.count == 2 ? symbols[1] : "PM"
    }
}

#endif

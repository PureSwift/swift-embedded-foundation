//
//  Platform.swift
//  FoundationEmbedded
//
//  The package's side of `FoundationEmbeddedPlatform.h`: each function a
//  platform defines, called with Swift's types. Compiled only with the
//  `PlatformHooks` trait.
//

#if PlatformHooks

import FoundationEmbeddedPlatform

enum Platform {

    // MARK: Text

    /// Calls `body` with the text's UTF-8 and its length.
    static func withUTF8<Result>(_ text: String, _ body: (UnsafePointer<UInt8>?, Int) -> Result) -> Result {
        var text = text
        return text.withUTF8 { body($0.baseAddress, $0.count) }
    }

    /// The text a function writes to a buffer. The function returns the
    /// length the text needs; if that's more than the buffer holds, it's
    /// asked again with one that size. Less than zero is no text.
    static func text(_ write: (UnsafeMutablePointer<UInt8>?, Int) -> Int) -> String? {
        var capacity = 64
        while true {
            let attempt: (needed: Int, text: String?) = withUnsafeTemporaryAllocation(of: UInt8.self, capacity: capacity) { buffer in
                let needed = write(buffer.baseAddress, capacity)
                guard needed >= 0, needed <= capacity else {
                    return (needed, nil)
                }
                return (needed, String(decoding: UnsafeBufferPointer(rebasing: buffer[..<needed]), as: UTF8.self))
            }
            if attempt.needed < 0 {
                return nil
            }
            if let text = attempt.text {
                return text
            }
            capacity = attempt.needed
        }
    }

    /// A list a function writes: its items with a line feed between.
    static func lines(_ write: (UnsafeMutablePointer<UInt8>?, Int) -> Int) -> [String] {
        guard let text = text(write), !text.isEmpty else {
            return []
        }
        var lines: [String] = []
        var line: [UInt8] = []
        for byte in text.utf8 {
            if byte == UInt8(ascii: "\n") {
                lines.append(String(decoding: line, as: UTF8.self))
                line.removeAll(keepingCapacity: true)
            } else {
                line.append(byte)
            }
        }
        lines.append(String(decoding: line, as: UTF8.self))
        return lines
    }

    static func seconds(_ date: Date) -> Double {
        date.timeIntervalSince1970
    }

    /// `nan` is no date.
    static func date(_ seconds: Double) -> Date? {
        seconds.isNaN ? nil : Date(timeIntervalSince1970: seconds)
    }

    // MARK: The clock

    static func now() -> Date {
        Date(timeIntervalSince1970: swift_embedded_clock_now())
    }

    // MARK: Time zones

    /// The user's zone. GMT if the platform names none.
    static func currentTimeZone() -> TimeZone {
        guard let identifier = text({ swift_embedded_timezone_current($0, $1) }), !identifier.isEmpty else {
            return .gmt
        }
        return TimeZone(identifier: identifier) ?? TimeZone(identifier: identifier, secondsFromGMT: 0, kind: .named)
    }

    static func isKnownTimeZone(_ identifier: String) -> Bool {
        withUTF8(identifier) { swift_embedded_timezone_is_known($0, $1) }
    }

    static func timeZoneIdentifiers() -> [String] {
        lines { swift_embedded_timezone_identifiers($0, $1) }
    }

    static func offset(of zone: TimeZone, at date: Date) -> Int {
        withUTF8(zone.identifier) { Int(swift_embedded_timezone_offset($0, $1, seconds(date))) }
    }

    static func daylightSavingOffset(of zone: TimeZone, at date: Date) -> Int {
        withUTF8(zone.identifier) { Int(swift_embedded_timezone_daylight_saving_offset($0, $1, seconds(date))) }
    }

    static func nextTransition(of zone: TimeZone, after date: Date) -> Date? {
        self.date(withUTF8(zone.identifier) { swift_embedded_timezone_next_transition($0, $1, seconds(date)) })
    }

    static func abbreviation(of zone: TimeZone, at date: Date) -> String? {
        withUTF8(zone.identifier) { identifier, length in
            text { swift_embedded_timezone_abbreviation(identifier, length, seconds(date), $0, $1) }
        }
    }

    static func name(of zone: TimeZone, style: TimeZone.NameStyle, locale: Locale?) -> String? {
        withUTF8(zone.identifier) { identifier, length in
            withUTF8(locale?.identifier ?? "") { locale, localeLength in
                text { swift_embedded_timezone_name(identifier, length, Int32(style.rawValue), locale, localeLength, $0, $1) }
            }
        }
    }

    // MARK: The locale

    /// The user's locale. The POSIX locale if the platform names none.
    static func currentLocale() -> Locale {
        guard let identifier = text({ swift_embedded_locale_current($0, $1) }), !identifier.isEmpty else {
            return Locale(identifier: "en_US_POSIX")
        }
        return Locale(identifier: identifier)
    }

    static func preferredLanguages() -> [String] {
        lines { swift_embedded_locale_preferred_languages($0, $1) }
    }

    // MARK: Calendars

    /// The user's calendar, in their zone and locale. Gregorian if the
    /// platform names one the package doesn't have.
    static func currentCalendar() -> Calendar {
        let name = text { swift_embedded_calendar_current($0, $1) } ?? ""
        return Calendar(identifier: Calendar.Identifier(name: name) ?? .gregorian)
    }

    /// Calls `body` with the calendar as the header has it.
    static func withCalendar<Result>(_ calendar: Calendar, _ body: (UnsafePointer<swift_embedded_calendar>) -> Result) -> Result {
        withUTF8(calendar.identifier.name) { identifier, identifierLength in
            withUTF8(calendar.timeZone.identifier) { zone, zoneLength in
                withUTF8(calendar.locale?.identifier ?? "") { locale, localeLength in
                    var value = swift_embedded_calendar(
                        identifier: identifier,
                        identifier_length: identifierLength,
                        time_zone: zone,
                        time_zone_length: zoneLength,
                        locale: locale,
                        locale_length: localeLength,
                        first_weekday: Int32(truncatingIfNeeded: calendar.storedFirstWeekday),
                        minimum_days: Int32(truncatingIfNeeded: calendar.storedMinimumDays)
                    )
                    return withUnsafePointer(to: &value) { body($0) }
                }
            }
        }
    }

    static func firstWeekday(of calendar: Calendar) -> Int {
        Int(withCalendar(calendar) { swift_embedded_calendar_first_weekday($0) })
    }

    static func minimumDays(of calendar: Calendar) -> Int {
        Int(withCalendar(calendar) { swift_embedded_calendar_minimum_days($0) })
    }

    /// A field that isn't given: the header's `SWIFT_EMBEDDED_FIELD_NONE`.
    static let none = Int.min

    static let fieldCount = 15

    static func noFields() -> [Int] {
        Array(repeating: none, count: fieldCount)
    }

    /// Every field of a moment; `nil` if the platform has no such calendar
    /// or zone.
    static func fields(of date: Date, in calendar: Calendar) -> [Int]? {
        var fields = noFields()
        let found = withCalendar(calendar) { calendar in
            fields.withUnsafeMutableBufferPointer { swift_embedded_calendar_fields(calendar, seconds(date), $0.baseAddress) }
        }
        return found ? fields : nil
    }

    static func date(from fields: [Int], in calendar: Calendar) -> Date? {
        date(withCalendar(calendar) { calendar in
            fields.withUnsafeBufferPointer { swift_embedded_calendar_date(calendar, $0.baseAddress) }
        })
    }

    static func adding(_ fields: [Int], to date: Date, wrapping: Bool, in calendar: Calendar) -> Date? {
        self.date(withCalendar(calendar) { calendar in
            fields.withUnsafeBufferPointer { swift_embedded_calendar_adding(calendar, $0.baseAddress, seconds(date), wrapping) }
        })
    }

    static func difference(_ units: Int32, from start: Date, to end: Date, in calendar: Calendar) -> [Int]? {
        var fields = noFields()
        let found = withCalendar(calendar) { calendar in
            fields.withUnsafeMutableBufferPointer {
                swift_embedded_calendar_difference(calendar, units, seconds(start), seconds(end), $0.baseAddress)
            }
        }
        return found ? fields : nil
    }

    static func start(of unit: Int32, containing date: Date, in calendar: Calendar) -> Date? {
        self.date(withCalendar(calendar) { swift_embedded_calendar_start($0, unit, seconds(date)) })
    }

    static func end(of unit: Int32, containing date: Date, in calendar: Calendar) -> Date? {
        self.date(withCalendar(calendar) { swift_embedded_calendar_end($0, unit, seconds(date)) })
    }

    static func range(of smaller: Int32, in larger: Int32, for date: Date, in calendar: Calendar) -> Range<Int>? {
        var lower = 0
        var count = 0
        let found = withCalendar(calendar) { swift_embedded_calendar_range($0, smaller, larger, seconds(date), &lower, &count) }
        guard found, count >= 0 else {
            return nil
        }
        return lower..<(lower + count)
    }

    static func ordinality(of smaller: Int32, in larger: Int32, for date: Date, in calendar: Calendar) -> Int? {
        let ordinality = Int(withCalendar(calendar) { swift_embedded_calendar_ordinality($0, smaller, larger, seconds(date)) })
        return ordinality == 0 ? nil : ordinality
    }

    static func nextDate(after date: Date, matching fields: [Int], policy: Int32, backward: Bool, in calendar: Calendar) -> Date? {
        self.date(withCalendar(calendar) { calendar in
            fields.withUnsafeBufferPointer {
                swift_embedded_calendar_next_date(calendar, seconds(date), $0.baseAddress, policy, backward)
            }
        })
    }

    static func isWeekend(_ date: Date, in calendar: Calendar) -> Bool {
        withCalendar(calendar) { swift_embedded_calendar_is_weekend($0, seconds(date)) }
    }

    static func symbols(_ kind: Int32, in calendar: Calendar) -> [String] {
        withCalendar(calendar) { calendar in
            lines { swift_embedded_calendar_symbols(calendar, kind, $0, $1) }
        }
    }
}

// MARK: - Fields

extension Calendar.Component {

    /// The component's place in the header's list of fields, which is also
    /// its number as a unit.
    var unit: Int32 {
        switch self {
        case .era: return 0
        case .year: return 1
        case .month: return 2
        case .day: return 3
        case .hour: return 4
        case .minute: return 5
        case .second: return 6
        case .nanosecond: return 7
        case .weekday: return 8
        case .weekdayOrdinal: return 9
        case .weekOfMonth: return 10
        case .weekOfYear: return 11
        case .yearForWeekOfYear: return 12
        case .dayOfYear: return 13
        }
    }

    static let all: [Calendar.Component] = [
        .era, .year, .month, .day, .hour, .minute, .second, .nanosecond,
        .weekday, .weekdayOrdinal, .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear,
    ]

    /// The place of the leap month, which isn't a component.
    static let leapMonthField = 14
}

extension DateComponents {

    /// The components as the header's fields.
    var fields: [Int] {
        var fields = Platform.noFields()
        for component in Calendar.Component.all {
            if let value = value(for: component) {
                fields[Int(component.unit)] = value
            }
        }
        if let isLeapMonth {
            fields[Calendar.Component.leapMonthField] = isLeapMonth ? 1 : 0
        }
        return fields
    }

    /// The fields the header gave, and of them only `components` if given.
    init(fields: [Int], only components: Set<Calendar.Component>? = nil) {
        self.init()
        for component in Calendar.Component.all {
            if let components, !components.contains(component) {
                continue
            }
            let value = fields[Int(component.unit)]
            if value != Platform.none {
                setValue(value, for: component)
            }
        }
        // A leap month is said only where there is one, with its month.
        if components?.contains(.month) != false, fields[Calendar.Component.leapMonthField] == 1 {
            isLeapMonth = true
        }
    }
}

extension Set where Element == Calendar.Component {

    /// The bit for each component, by its unit.
    var units: Int32 {
        var units: Int32 = 0
        for component in self {
            units |= 1 << component.unit
        }
        return units
    }
}

#endif

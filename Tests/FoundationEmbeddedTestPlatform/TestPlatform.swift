//
//  TestPlatform.swift
//  FoundationEmbeddedTestPlatform
//
//  A platform for the tests: `FoundationEmbeddedPlatform.h` over Foundation
//  itself. Built with the `PlatformHooks` trait, the package's tests link
//  it, so that the package's types answer through the header and can be
//  compared with Foundation's own.
//

import Foundation
import FoundationEmbeddedPlatform

/// What the test platform says the user's settings are.
public enum TestPlatform {

    /// Seconds since 1970; `nil` for the system's clock.
    nonisolated(unsafe) public static var now: Double?

    nonisolated(unsafe) public static var timeZone = "Europe/Berlin"

    nonisolated(unsafe) public static var locale = "en_US"

    nonisolated(unsafe) public static var calendar = "gregorian"

    nonisolated(unsafe) public static var preferredLanguages = ["en-US", "de-DE"]

    /// How many times the package asked about a calendar or a zone.
    nonisolated(unsafe) public static var calls = 0

    public static func reset() {
        now = nil
        timeZone = "Europe/Berlin"
        locale = "en_US"
        calendar = "gregorian"
        preferredLanguages = ["en-US", "de-DE"]
    }

    // MARK: Conversions

    static func string(_ bytes: UnsafePointer<UInt8>?, _ length: Int) -> String {
        guard let bytes, length > 0 else { return "" }
        return String(decoding: UnsafeBufferPointer(start: bytes, count: length), as: UTF8.self)
    }

    /// Writes what fits and returns what the text needs; -1 for no text.
    static func write(_ text: String?, _ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
        guard let text else { return -1 }
        let utf8 = Array(text.utf8)
        if let buffer, utf8.count <= capacity {
            for (index, byte) in utf8.enumerated() {
                buffer[index] = byte
            }
        }
        return utf8.count
    }

    static func zone(_ identifier: UnsafePointer<UInt8>?, _ length: Int) -> Foundation.TimeZone? {
        calls += 1
        return Foundation.TimeZone(identifier: string(identifier, length))
    }

    static func date(_ seconds: Double) -> Foundation.Date {
        Foundation.Date(timeIntervalSince1970: seconds.isFinite ? seconds : 0)
    }

    static let identifiers: [String: Foundation.Calendar.Identifier] = [
        "gregorian": .gregorian, "iso8601": .iso8601, "buddhist": .buddhist, "chinese": .chinese,
        "coptic": .coptic, "ethiopic": .ethiopicAmeteMihret, "ethioaa": .ethiopicAmeteAlem, "hebrew": .hebrew,
        "indian": .indian, "islamic": .islamic, "islamic-civil": .islamicCivil, "islamic-tbla": .islamicTabular,
        "islamic-umalqura": .islamicUmmAlQura, "japanese": .japanese, "persian": .persian, "roc": .republicOfChina,
    ]

    static func calendar(_ pointer: UnsafePointer<swift_embedded_calendar>?) -> Foundation.Calendar? {
        guard let value = pointer?.pointee,
              let identifier = identifiers[string(value.identifier, value.identifier_length)],
              let zone = zone(value.time_zone, value.time_zone_length) else {
            return nil
        }
        var calendar = Foundation.Calendar(identifier: identifier)
        let locale = string(value.locale, value.locale_length)
        calendar.locale = Foundation.Locale(identifier: locale.isEmpty ? TestPlatform.locale : locale)
        calendar.timeZone = zone
        if value.first_weekday != 0 {
            calendar.firstWeekday = Int(value.first_weekday)
        }
        if value.minimum_days != 0 {
            calendar.minimumDaysInFirstWeek = Int(value.minimum_days)
        }
        return calendar
    }

    static let none = Int.min

    static let fieldCount = 15

    static func component(_ unit: Int32) -> Foundation.Calendar.Component? {
        switch unit {
        case 0: return .era
        case 1: return .year
        case 2: return .month
        case 3: return .day
        case 4: return .hour
        case 5: return .minute
        case 6: return .second
        case 7: return .nanosecond
        case 8: return .weekday
        case 9: return .weekdayOrdinal
        case 10: return .weekOfMonth
        case 11: return .weekOfYear
        case 12: return .yearForWeekOfYear
        case 13: return .dayOfYear
        default: return nil
        }
    }

    static func components(_ fields: UnsafePointer<Int>?) -> Foundation.DateComponents {
        var components = Foundation.DateComponents()
        guard let fields else { return components }
        for unit in 0..<14 {
            let value = fields[unit]
            guard value != none, let component = component(Int32(unit)) else { continue }
            components.setValue(value, for: component)
        }
        if fields[14] != none {
            components.isLeapMonth = fields[14] != 0
        }
        return components
    }

    static func isEmpty(_ fields: UnsafePointer<Int>?) -> Bool {
        guard let fields else { return true }
        return !(0..<fieldCount).contains { fields[$0] != none }
    }

    static func store(_ components: Foundation.DateComponents, in fields: UnsafeMutablePointer<Int>?) {
        guard let fields else { return }
        for unit in 0..<14 {
            fields[unit] = component(Int32(unit)).flatMap { components.value(for: $0) } ?? none
        }
        fields[14] = components.isLeapMonth.map { $0 ? 1 : 0 } ?? none
    }
}

// MARK: - The clock

@c @implementation
public func swift_embedded_clock_now() -> Double {
    TestPlatform.now ?? Foundation.Date().timeIntervalSince1970
}

// MARK: - Time zones

@c @implementation
public func swift_embedded_timezone_current(_ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
    TestPlatform.write(TestPlatform.timeZone, buffer, capacity)
}

@c @implementation
public func swift_embedded_timezone_is_known(_ identifier: UnsafePointer<UInt8>?, _ length: Int) -> Bool {
    TestPlatform.zone(identifier, length) != nil
}

@c @implementation
public func swift_embedded_timezone_identifiers(_ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
    TestPlatform.write(Foundation.TimeZone.knownTimeZoneIdentifiers.sorted().joined(separator: "\n"), buffer, capacity)
}

@c @implementation
public func swift_embedded_timezone_offset(_ identifier: UnsafePointer<UInt8>?, _ length: Int, _ seconds: Double) -> Int32 {
    Int32(TestPlatform.zone(identifier, length)?.secondsFromGMT(for: TestPlatform.date(seconds)) ?? 0)
}

@c @implementation
public func swift_embedded_timezone_daylight_saving_offset(_ identifier: UnsafePointer<UInt8>?, _ length: Int, _ seconds: Double) -> Int32 {
    Int32(TestPlatform.zone(identifier, length)?.daylightSavingTimeOffset(for: TestPlatform.date(seconds)) ?? 0)
}

@c @implementation
public func swift_embedded_timezone_next_transition(_ identifier: UnsafePointer<UInt8>?, _ length: Int, _ seconds: Double) -> Double {
    TestPlatform.zone(identifier, length)?
        .nextDaylightSavingTimeTransition(after: TestPlatform.date(seconds))?.timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_timezone_abbreviation(
    _ identifier: UnsafePointer<UInt8>?, _ length: Int, _ seconds: Double,
    _ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int
) -> Int {
    TestPlatform.write(TestPlatform.zone(identifier, length)?.abbreviation(for: TestPlatform.date(seconds)), buffer, capacity)
}

@c @implementation
public func swift_embedded_timezone_name(
    _ identifier: UnsafePointer<UInt8>?, _ length: Int, _ style: Int32,
    _ locale: UnsafePointer<UInt8>?, _ localeLength: Int,
    _ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int
) -> Int {
    guard let zone = TestPlatform.zone(identifier, length), let style = NSTimeZone.NameStyle(rawValue: Int(style)) else {
        return -1
    }
    let name = TestPlatform.string(locale, localeLength)
    return TestPlatform.write(
        zone.localizedName(for: style, locale: Foundation.Locale(identifier: name.isEmpty ? TestPlatform.locale : name)),
        buffer, capacity)
}

// MARK: - The locale

@c @implementation
public func swift_embedded_locale_current(_ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
    TestPlatform.write(TestPlatform.locale, buffer, capacity)
}

@c @implementation
public func swift_embedded_locale_preferred_languages(_ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
    TestPlatform.write(TestPlatform.preferredLanguages.joined(separator: "\n"), buffer, capacity)
}

// MARK: - Calendars

@c @implementation
public func swift_embedded_calendar_current(_ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int) -> Int {
    TestPlatform.write(TestPlatform.calendar, buffer, capacity)
}

@c @implementation
public func swift_embedded_calendar_first_weekday(_ calendar: UnsafePointer<swift_embedded_calendar>?) -> Int32 {
    Int32(TestPlatform.calendar(calendar)?.firstWeekday ?? 1)
}

@c @implementation
public func swift_embedded_calendar_minimum_days(_ calendar: UnsafePointer<swift_embedded_calendar>?) -> Int32 {
    Int32(TestPlatform.calendar(calendar)?.minimumDaysInFirstWeek ?? 1)
}

@c @implementation
public func swift_embedded_calendar_fields(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ seconds: Double, _ fields: UnsafeMutablePointer<Int>?
) -> Bool {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite else { return false }
    let date = TestPlatform.date(seconds)
    var components = calendar.dateComponents(
        [.era, .year, .month, .day, .hour, .minute, .second, .nanosecond, .weekday, .weekdayOrdinal,
         .weekOfMonth, .weekOfYear, .yearForWeekOfYear, .dayOfYear],
        from: date)
    components.isLeapMonth = components.isLeapMonth ?? false
    TestPlatform.store(components, in: fields)
    return true
}

@c @implementation
public func swift_embedded_calendar_date(_ calendar: UnsafePointer<swift_embedded_calendar>?, _ fields: UnsafePointer<Int>?) -> Double {
    guard let calendar = TestPlatform.calendar(calendar), !TestPlatform.isEmpty(fields) else { return .nan }
    return calendar.date(from: TestPlatform.components(fields))?.timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_calendar_adding(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ fields: UnsafePointer<Int>?, _ seconds: Double, _ wrapping: Bool
) -> Double {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite else { return .nan }
    if TestPlatform.isEmpty(fields) { return seconds }
    return calendar.date(byAdding: TestPlatform.components(fields), to: TestPlatform.date(seconds), wrappingComponents: wrapping)?
        .timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_calendar_difference(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ units: Int32, _ start: Double, _ end: Double,
    _ fields: UnsafeMutablePointer<Int>?
) -> Bool {
    guard let calendar = TestPlatform.calendar(calendar), start.isFinite, end.isFinite else { return false }
    var components: Set<Foundation.Calendar.Component> = []
    for unit in 0..<14 where units & (1 << Int32(unit)) != 0 {
        if let component = TestPlatform.component(Int32(unit)) {
            components.insert(component)
        }
    }
    guard !components.isEmpty else { return false }
    TestPlatform.store(calendar.dateComponents(components, from: TestPlatform.date(start), to: TestPlatform.date(end)), in: fields)
    return true
}

@c @implementation
public func swift_embedded_calendar_start(_ calendar: UnsafePointer<swift_embedded_calendar>?, _ unit: Int32, _ seconds: Double) -> Double {
    guard let calendar = TestPlatform.calendar(calendar), let component = TestPlatform.component(unit), seconds.isFinite else {
        return .nan
    }
    return calendar.dateInterval(of: component, for: TestPlatform.date(seconds))?.start.timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_calendar_end(_ calendar: UnsafePointer<swift_embedded_calendar>?, _ unit: Int32, _ seconds: Double) -> Double {
    guard let calendar = TestPlatform.calendar(calendar), let component = TestPlatform.component(unit), seconds.isFinite else {
        return .nan
    }
    return calendar.dateInterval(of: component, for: TestPlatform.date(seconds))?.end.timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_calendar_range(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ smaller: Int32, _ larger: Int32, _ seconds: Double,
    _ lower: UnsafeMutablePointer<Int>?, _ count: UnsafeMutablePointer<Int>?
) -> Bool {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite,
          let smaller = TestPlatform.component(smaller), let larger = TestPlatform.component(larger),
          let range = calendar.range(of: smaller, in: larger, for: TestPlatform.date(seconds)) else {
        return false
    }
    lower?.pointee = range.lowerBound
    count?.pointee = range.count
    return true
}

@c @implementation
public func swift_embedded_calendar_ordinality(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ smaller: Int32, _ larger: Int32, _ seconds: Double
) -> Int32 {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite,
          let smaller = TestPlatform.component(smaller), let larger = TestPlatform.component(larger) else {
        return 0
    }
    return Int32(calendar.ordinality(of: smaller, in: larger, for: TestPlatform.date(seconds)) ?? 0)
}

@c @implementation
public func swift_embedded_calendar_next_date(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ seconds: Double, _ fields: UnsafePointer<Int>?,
    _ policy: Int32, _ backward: Bool
) -> Double {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite, !TestPlatform.isEmpty(fields) else { return .nan }
    let matching: Foundation.Calendar.MatchingPolicy
    switch policy {
    case 0: matching = .nextTime
    case 1: matching = .nextTimePreservingSmallerComponents
    case 2: matching = .previousTimePreservingSmallerComponents
    case 3: matching = .strict
    default: return .nan
    }
    return calendar.nextDate(
        after: TestPlatform.date(seconds), matching: TestPlatform.components(fields), matchingPolicy: matching,
        repeatedTimePolicy: .first, direction: backward ? .backward : .forward)?.timeIntervalSince1970 ?? .nan
}

@c @implementation
public func swift_embedded_calendar_is_weekend(_ calendar: UnsafePointer<swift_embedded_calendar>?, _ seconds: Double) -> Bool {
    guard let calendar = TestPlatform.calendar(calendar), seconds.isFinite else { return false }
    return calendar.isDateInWeekend(TestPlatform.date(seconds))
}

@c @implementation
public func swift_embedded_calendar_symbols(
    _ calendar: UnsafePointer<swift_embedded_calendar>?, _ kind: Int32,
    _ buffer: UnsafeMutablePointer<UInt8>?, _ capacity: Int
) -> Int {
    guard let calendar = TestPlatform.calendar(calendar) else { return -1 }
    let symbols: [String]
    switch kind {
    case 0: symbols = calendar.monthSymbols
    case 1: symbols = calendar.shortMonthSymbols
    case 2: symbols = calendar.veryShortMonthSymbols
    case 3: symbols = calendar.standaloneMonthSymbols
    case 4: symbols = calendar.shortStandaloneMonthSymbols
    case 5: symbols = calendar.veryShortStandaloneMonthSymbols
    case 6: symbols = calendar.weekdaySymbols
    case 7: symbols = calendar.shortWeekdaySymbols
    case 8: symbols = calendar.veryShortWeekdaySymbols
    case 9: symbols = calendar.standaloneWeekdaySymbols
    case 10: symbols = calendar.shortStandaloneWeekdaySymbols
    case 11: symbols = calendar.veryShortStandaloneWeekdaySymbols
    case 12: symbols = calendar.eraSymbols
    case 13: symbols = calendar.longEraSymbols
    case 14: symbols = [calendar.amSymbol, calendar.pmSymbol]
    default: return -1
    }
    return TestPlatform.write(symbols.joined(separator: "\n"), buffer, capacity)
}

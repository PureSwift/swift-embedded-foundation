//
//  Platform/main.swift
//  FoundationEmbedded — Embedded Swift smoke test, with a platform
//
//  The package built with the `PlatformHooks` trait under real Embedded
//  Swift, linked with the platform in `platform.c` beside it. It proves that the
//  package and a platform written in C meet at the linker, and that a
//  platform which knows little leaves the package answering "no result".
//  `Scripts/embedded-test.sh` compiles and runs it.
//

func check(_ condition: Bool, _ message: StaticString) {
    precondition(condition, message)
}

// MARK: The clock

check(Date().timeIntervalSince1970 == 1774701005, "Date() is the platform's clock")
check(Date.now == Date(timeIntervalSince1970: 1774701005), "Date.now")

// MARK: Time zones

let zone = TimeZone.current
check(zone.identifier == "Board/Local", "TimeZone current")
check(zone.secondsFromGMT(for: Date.now) == 3600, "TimeZone offset from the platform")
check(TimeZone(identifier: "Board/Local") == zone, "TimeZone by name")
check(TimeZone(identifier: "Europe/Berlin") == nil, "TimeZone the platform doesn't know")
check(TimeZone(secondsFromGMT: 7200)?.secondsFromGMT(for: Date.now) == 7200, "TimeZone fixed stays the package's")
check(TimeZone.knownTimeZoneIdentifiers == ["Board/Local"], "TimeZone identifiers")
check(!zone.isDaylightSavingTime(for: Date.now), "TimeZone daylight saving")
check(zone.nextDaylightSavingTimeTransition(after: Date.now) == nil, "TimeZone no transition")
check(zone.abbreviation(for: Date.now) == nil, "TimeZone no abbreviation")

// MARK: The locale

check(Locale.current.identifier == "en_GB", "Locale current")
check(Locale.preferredLanguages == ["en-GB", "de-DE"], "Locale preferred languages")

// MARK: Calendars

let calendar = Calendar.current
check(calendar.identifier == .gregorian, "Calendar current")
check(calendar.timeZone == zone, "Calendar zone")
check(calendar.firstWeekday == 2, "Calendar first weekday from the platform")
check(calendar.minimumDaysInFirstWeek == 4, "Calendar minimum days from the platform")
// This platform does no arithmetic, and the package doesn't trap for it.
check(calendar.date(from: DateComponents(year: 2026, month: 3, day: 28)) == nil, "Calendar no date")
check(calendar.dateComponents([.year], from: Date.now) == DateComponents(), "Calendar no components")
check(calendar.dateInterval(of: .month, for: Date.now) == nil, "Calendar no interval")
check(calendar.range(of: .day, in: .month, for: Date.now) == nil, "Calendar no range")
check(calendar.monthSymbols.isEmpty, "Calendar no symbols")
check(calendar.amSymbol == "AM", "Calendar AM without a platform's word")

// MARK: The package's own formats need no platform

check(Date.ISO8601FormatStyle().format(Date.now) == "2026-03-28T12:30:05Z", "ISO 8601")
check(Date.HTTPFormatStyle().format(Date.now) == "Sat, 28 Mar 2026 12:30:05 GMT", "HTTP date")
check(Date.now.description == "2026-03-28 12:30:05 +0000", "Date description")

print("FoundationEmbedded embedded smoke test with a platform: all checks passed")

#if PlatformHooks && canImport(Foundation)
import Foundation
import FoundationEmbeddedTestPlatform
import Testing
@testable import FoundationEmbedded

/// The package built with the `PlatformHooks` trait, over a platform the
/// tests supply: `FoundationEmbeddedPlatform.h` defined over Foundation.
///
/// Serialized: the tests set what the platform says the user's settings
/// are.
@Suite(.serialized) struct PlatformHooksTests {

    typealias Date = FoundationEmbedded.Date
    typealias TimeZone = FoundationEmbedded.TimeZone
    typealias Locale = FoundationEmbedded.Locale
    typealias Calendar = FoundationEmbedded.Calendar
    typealias DateComponents = FoundationEmbedded.DateComponents

    static func at(_ text: String) -> Date {
        Date(timeIntervalSince1970: ISO8601DateFormatter().date(from: text)!.timeIntervalSince1970)
    }

    /// 13:30:05 on Saturday 28 March 2026 in Berlin, the day before its
    /// clocks go forward.
    static let saturday = at("2026-03-28T12:30:05Z")

    func berlin(_ identifier: Calendar.Identifier = .gregorian, locale: String = "en_US") -> Calendar {
        var calendar = Calendar(identifier: identifier)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        calendar.locale = Locale(identifier: locale)
        return calendar
    }

    init() {
        TestPlatform.reset()
    }

    // MARK: The clock

    @Test func theClock() {
        defer { TestPlatform.reset() }
        #expect(abs(Date().timeIntervalSince1970 - Foundation.Date().timeIntervalSince1970) < 5)
        TestPlatform.now = Self.saturday.timeIntervalSince1970
        #expect(Date() == Self.saturday)
        #expect(Date.now == Self.saturday)
        #expect(Self.at("2026-03-28T12:30:00Z").timeIntervalSinceNow == -5)
    }

    // MARK: Time zones

    @Test func theUsersZone() {
        defer { TestPlatform.reset() }
        #expect(TimeZone.current.identifier == "Europe/Berlin")
        #expect(TimeZone.current.kind == .named)
        TestPlatform.timeZone = "Asia/Tokyo"
        #expect(TimeZone.current.identifier == "Asia/Tokyo")
        #expect(TimeZone.current.secondsFromGMT(for: Self.saturday) == 9 * 3600)
        // A fixed offset stays the package's own.
        TestPlatform.timeZone = "GMT+0100"
        #expect(TimeZone.current.kind == .fixed)
        #expect(TimeZone.current.secondsFromGMT(for: Self.saturday) == 3600)
        // A platform that names none, or one it doesn't know itself.
        TestPlatform.timeZone = ""
        #expect(TimeZone.current == .gmt)
        TestPlatform.timeZone = "Mars/Olympus"
        #expect(TimeZone.current.identifier == "Mars/Olympus")
        #expect(TimeZone.current.secondsFromGMT(for: Self.saturday) == 0)
    }

    @Test func namedZones() throws {
        let berlin = try #require(TimeZone(identifier: "Europe/Berlin"))
        let summer = Self.at("2026-07-01T12:00:00Z")
        #expect(berlin.identifier == "Europe/Berlin")
        #expect(berlin.secondsFromGMT(for: Self.saturday) == 3600)
        #expect(berlin.secondsFromGMT(for: summer) == 7200)
        #expect(!berlin.isDaylightSavingTime(for: Self.saturday))
        #expect(berlin.isDaylightSavingTime(for: summer))
        #expect(berlin.daylightSavingTimeOffset(for: summer) == 3600)
        #expect(berlin.nextDaylightSavingTimeTransition(after: Self.saturday) == Self.at("2026-03-29T01:00:00Z"))
        #expect(berlin.abbreviation(for: Self.saturday)?.isEmpty == false)
        #expect(berlin.localizedName(for: .generic, locale: Locale(identifier: "en_US")) == "Central European Time")
        #expect(berlin.localizedName(for: .daylightSaving, locale: Locale(identifier: "de_DE")) == "Mitteleuropäische Sommerzeit")
        #expect(berlin.localizedName(for: .standard, locale: nil) == "Central European Standard Time", "the user's locale")
        #expect(berlin.debugDescription == "Europe/Berlin")
        #expect(berlin == TimeZone(identifier: "Europe/Berlin"))
        #expect(berlin != TimeZone(identifier: "Europe/Paris"))

        #expect(TimeZone(identifier: "Mars/Olympus") == nil)
        #expect(TimeZone(identifier: "") == nil)

        // A fixed zone has no daylight saving and no changes to come.
        let fixed = try #require(TimeZone(secondsFromGMT: 3600))
        #expect(fixed.kind == .fixed)
        #expect(!fixed.isDaylightSavingTime(for: summer))
        #expect(fixed.nextDaylightSavingTimeTransition(after: summer) == nil)
        #expect(TimeZone.gmt.nextDaylightSavingTimeTransition(after: summer) == nil)

        // A list longer than the first buffer.
        let all = TimeZone.knownTimeZoneIdentifiers
        #expect(all.count > 300)
        #expect(all.contains("Asia/Tokyo"))
        #expect(all.contains("America/New_York"))
        #expect(all == all.sorted())
    }

    // MARK: The locale

    @Test func theUsersLocale() {
        defer { TestPlatform.reset() }
        #expect(Locale.current.identifier == "en_US")
        #expect(Locale.preferredLanguages == ["en-US", "de-DE"])
        TestPlatform.locale = "de_DE"
        TestPlatform.preferredLanguages = []
        #expect(Locale.current.identifier == "de_DE")
        #expect(Locale.preferredLanguages.isEmpty)
        TestPlatform.locale = ""
        #expect(Locale.current.identifier == "en_US_POSIX")
    }

    // MARK: Calendars

    @Test func theUsersCalendar() {
        defer { TestPlatform.reset() }
        let calendar = Calendar.current
        #expect(calendar.identifier == .gregorian)
        #expect(calendar.timeZone.identifier == "Europe/Berlin")
        #expect(calendar.locale?.identifier == "en_US")
        #expect(calendar.firstWeekday == 1)
        #expect(calendar.minimumDaysInFirstWeek == 1)

        TestPlatform.calendar = "buddhist"
        TestPlatform.locale = "en_GB"
        #expect(Calendar.current.identifier == .buddhist)
        #expect(Calendar.current.firstWeekday == 2)
        #expect(Calendar.current.component(.year, from: Self.saturday) == 2569)

        // One the package has no name for.
        TestPlatform.calendar = "martian"
        #expect(Calendar.current.identifier == .gregorian)
    }

    @Test func identifiers() {
        for identifier in Calendar.Identifier.all {
            #expect(Calendar.Identifier(name: identifier.name) == identifier)
            #expect(berlin(identifier).component(.day, from: Self.saturday) > 0, "\(identifier.name)")
        }
        #expect(Calendar.Identifier(name: "martian") == nil)
        #expect(Calendar.Identifier.all.count == 16)
    }

    @Test func weeks() {
        #expect(berlin(locale: "en_US").firstWeekday == 1)
        #expect(berlin(locale: "en_GB").firstWeekday == 2)
        var calendar = berlin(locale: "en_US")
        calendar.firstWeekday = 7
        calendar.minimumDaysInFirstWeek = 4
        #expect(calendar.firstWeekday == 7)
        #expect(calendar.minimumDaysInFirstWeek == 4)

        // ISO 8601: weeks start on Monday, and the first has a Thursday.
        let iso = berlin(.iso8601)
        #expect(iso.firstWeekday == 2)
        #expect(iso.minimumDaysInFirstWeek == 4)
        let newYear = iso.dateComponents([.year, .weekOfYear, .yearForWeekOfYear], from: Self.at("2027-01-01T12:00:00Z"))
        #expect(newYear.weekOfYear == 53)
        #expect(newYear.yearForWeekOfYear == 2026)
        #expect(newYear.year == 2027)
        // The week it starts with follows the calendar.
        #expect(berlin().dateInterval(of: .weekOfYear, for: Self.saturday)?.start == Self.at("2026-03-21T23:00:00Z"))
        #expect(calendar.dateInterval(of: .weekOfYear, for: Self.saturday)?.start == Self.at("2026-03-27T23:00:00Z"))
        #expect(iso.dateInterval(of: .weekOfYear, for: Self.saturday)?.start == Self.at("2026-03-22T23:00:00Z"))
    }

    @Test func componentsOfADate() {
        let calendar = berlin()
        let all = calendar.dateComponents(Set(Calendar.Component.all), from: Self.saturday)
        #expect(all.era == 1)
        #expect(all.year == 2026)
        #expect(all.month == 3)
        #expect(all.day == 28)
        #expect(all.hour == 13)
        #expect(all.minute == 30)
        #expect(all.second == 5)
        #expect(all.nanosecond == 0)
        #expect(all.weekday == 7)
        #expect(all.weekdayOrdinal == 4)
        #expect(all.weekOfMonth == 4)
        #expect(all.weekOfYear == 13)
        #expect(all.yearForWeekOfYear == 2026)
        #expect(all.dayOfYear == 87)
        #expect(all.isLeapMonth == nil)
        #expect(all.timeZone == nil)

        // Only what was asked for, as in Foundation.
        let some = calendar.dateComponents([.year, .weekday], from: Self.saturday)
        #expect(some.year == 2026)
        #expect(some.weekday == 7)
        #expect(some.month == nil)
        #expect(some.hour == nil)
        #expect(calendar.dateComponents([], from: Self.saturday) == DateComponents())

        #expect(calendar.component(.dayOfYear, from: Self.saturday) == 87)
        #expect(calendar.component(.weekOfYear, from: Self.saturday) == 13)
        #expect(calendar.component(.hour, from: Self.at("2026-07-01T12:00:00Z")) == 14)

        // As Foundation has them.
        var theirs = Foundation.Calendar(identifier: .gregorian)
        theirs.timeZone = Foundation.TimeZone(identifier: "Europe/Berlin")!
        theirs.locale = Foundation.Locale(identifier: "en_US")
        for text in ["2026-03-29T00:59:59Z", "2026-03-29T01:00:00Z", "2026-10-25T01:00:00Z", "1965-07-01T12:00:00Z", "2100-02-28T23:30:00Z"] {
            let date = Self.at(text)
            let foundation = theirs.dateComponents(
                [.year, .month, .day, .hour, .minute, .weekday, .weekOfYear],
                from: Foundation.Date(timeIntervalSince1970: date.timeIntervalSince1970))
            let ours = calendar.dateComponents([.year, .month, .day, .hour, .minute, .weekday, .weekOfYear], from: date)
            #expect(ours.year == foundation.year, "\(text)")
            #expect(ours.day == foundation.day, "\(text)")
            #expect(ours.hour == foundation.hour, "\(text)")
            #expect(ours.weekday == foundation.weekday, "\(text)")
            #expect(ours.weekOfYear == foundation.weekOfYear, "\(text)")
        }
    }

    @Test func aDateFromComponents() {
        let calendar = berlin()
        #expect(calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 13, minute: 30, second: 5)) == Self.saturday)
        #expect(calendar.date(from: DateComponents(year: 2026, month: 3)) == Self.at("2026-02-28T23:00:00Z"), "the first of the month")
        var dayOfYear = DateComponents(year: 2026)
        dayOfYear.dayOfYear = 87
        #expect(calendar.date(from: dayOfYear) == Self.at("2026-03-27T23:00:00Z"))
        #expect(calendar.date(from: DateComponents()) == nil)

        // The night the clocks go forward has no 02:30, and the night
        // they go back has two.
        #expect(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 2, minute: 30)) == Self.at("2026-03-29T01:30:00Z"))
        #expect(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 2, minute: 30)) == Self.at("2026-10-25T00:30:00Z"))

        // The components' own zone and calendar.
        let tokyo = DateComponents(year: 2026, month: 3, day: 28, hour: 21, minute: 30, second: 5, timeZone: TimeZone(identifier: "Asia/Tokyo"))
        #expect(calendar.date(from: tokyo) == Self.saturday)
        #expect(DateComponents(calendar: calendar, year: 2026, month: 3, day: 28, hour: 13, minute: 30, second: 5).date == Self.saturday)
        #expect(DateComponents(year: 2026, month: 3, day: 28).date == nil)

        // A calendar or a zone the platform doesn't have.
        var nowhere = calendar
        nowhere.timeZone = TimeZone(identifier: "Mars/Olympus", secondsFromGMT: 0, kind: .named)
        #expect(nowhere.date(from: DateComponents(year: 2026, month: 3, day: 28)) == nil)
        #expect(nowhere.dateComponents([.year], from: Self.saturday) == DateComponents())
        #expect(nowhere.component(.year, from: Self.saturday) == 0)
        #expect(nowhere.startOfDay(for: Self.saturday) == Self.saturday)
    }

    @Test func adding() {
        let calendar = berlin()
        #expect(calendar.date(byAdding: .month, value: 1, to: Self.at("2026-01-31T11:00:00Z")) == Self.at("2026-02-28T11:00:00Z"))
        #expect(calendar.date(byAdding: .month, value: 1, to: Self.at("2024-01-31T11:00:00Z")) == Self.at("2024-02-29T11:00:00Z"))
        #expect(calendar.date(byAdding: .year, value: 1, to: Self.at("2024-02-29T11:00:00Z")) == Self.at("2025-02-28T11:00:00Z"))

        // A day keeps the time on the clock; 24 hours are 24 hours.
        let noon = Self.at("2026-03-28T11:00:00Z")
        #expect(calendar.date(byAdding: .day, value: 1, to: noon) == Self.at("2026-03-29T10:00:00Z"))
        #expect(calendar.date(byAdding: .hour, value: 24, to: noon) == Self.at("2026-03-29T11:00:00Z"))
        #expect(calendar.date(byAdding: .weekOfYear, value: 1, to: noon) == Self.at("2026-04-04T10:00:00Z"))
        #expect(calendar.date(byAdding: DateComponents(month: 1, day: 2, hour: 3), to: noon) == Self.at("2026-04-30T13:00:00Z"))

        // The fraction of a second comes back.
        #expect(calendar.date(byAdding: .day, value: 2, to: noon + 0.25) == Self.at("2026-03-30T10:00:00Z") + 0.25)

        // Wrapping doesn't carry.
        #expect(calendar.date(byAdding: .day, value: 1, to: Self.at("2026-01-31T11:00:00Z"), wrappingComponents: true)
            == Self.at("2026-01-01T11:00:00Z"))
        #expect(calendar.date(byAdding: DateComponents(), to: noon) == noon)
        #expect(calendar.date(byAdding: .era, value: 1, to: noon) == nil)
        #expect(calendar.date(byAdding: .weekday, value: 1, to: noon) == nil)
    }

    @Test func differences() {
        let calendar = berlin()
        let start = Self.at("2024-03-01T11:00:00Z")
        #expect(calendar.dateComponents([.day], from: start, to: Self.saturday).day == 757)
        let parts = calendar.dateComponents([.year, .month, .day], from: start, to: Self.saturday)
        #expect(parts.year == 2)
        #expect(parts.month == 0)
        #expect(parts.day == 27)
        #expect(parts.hour == nil)
        #expect(calendar.dateComponents([.hour], from: Self.saturday, to: Self.saturday - 7200).hour == -2)
        #expect(calendar.dateComponents([], from: start, to: Self.saturday) == DateComponents())
    }

    @Test func intervalsRangesAndOrdinals() {
        let calendar = berlin()
        let month = calendar.dateInterval(of: .month, for: Self.saturday)
        #expect(month?.start == Self.at("2026-02-28T23:00:00Z"))
        #expect(month?.end == Self.at("2026-03-31T22:00:00Z"), "April begins in summer time")
        #expect(calendar.startOfDay(for: Self.saturday) == Self.at("2026-03-27T23:00:00Z"))
        // The day the clocks go forward has 23 hours.
        let short = calendar.dateInterval(of: .day, for: Self.at("2026-03-29T10:00:00Z"))
        #expect(short?.start == Self.at("2026-03-28T23:00:00Z"))
        #expect(short?.end == Self.at("2026-03-29T22:00:00Z"))
        let duration: TimeInterval? = short?.duration
        let twentyThreeHours: TimeInterval = 23 * 3600
        #expect(duration == twentyThreeHours)
        #expect(calendar.isDate(Self.saturday, inSameDayAs: Self.at("2026-03-28T22:30:00Z")))
        #expect(!calendar.isDate(Self.saturday, inSameDayAs: Self.at("2026-03-28T23:30:00Z")))

        #expect(calendar.range(of: .day, in: .month, for: Self.saturday) == 1..<32)
        #expect(calendar.range(of: .day, in: .month, for: Self.at("2024-02-10T12:00:00Z")) == 1..<30)
        #expect(calendar.range(of: .month, in: .year, for: Self.saturday) == 1..<13)
        #expect(calendar.ordinality(of: .day, in: .year, for: Self.saturday) == 87)
        #expect(calendar.ordinality(of: .day, in: .month, for: Self.saturday) == 28)
        #expect(calendar.range(of: .year, in: .day, for: Self.saturday) == nil)

        #expect(calendar.compare(Self.saturday, to: Self.at("2026-03-28T22:00:00Z"), toGranularity: .day) == .orderedSame)
        #expect(calendar.compare(Self.saturday, to: Self.at("2026-03-28T23:30:00Z"), toGranularity: .day) == .orderedAscending)
        #expect(calendar.compare(Self.saturday, to: Self.at("2026-03-01T00:00:00Z"), toGranularity: .month) == .orderedSame)
        #expect(calendar.compare(Self.saturday, to: Self.at("2025-12-31T00:00:00Z"), toGranularity: .year) == .orderedDescending)
        #expect(calendar.isDate(Self.saturday, equalTo: Self.at("2026-03-28T12:59:59Z"), toGranularity: .hour))
        #expect(!calendar.isDate(Self.saturday, equalTo: Self.at("2026-03-28T13:00:00Z"), toGranularity: .hour))
    }

    @Test func theNextMatch() {
        let calendar = berlin()
        let seven = DateComponents(hour: 7, minute: 0)
        #expect(calendar.nextDate(after: Self.saturday, matching: seven, matchingPolicy: .nextTime) == Self.at("2026-03-29T05:00:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: seven, matchingPolicy: .nextTime, direction: .backward) == Self.at("2026-03-28T06:00:00Z"))

        // 02:30 doesn't exist the next morning.
        let missing = DateComponents(hour: 2, minute: 30)
        #expect(calendar.nextDate(after: Self.saturday, matching: missing, matchingPolicy: .nextTime) == Self.at("2026-03-29T01:00:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: missing, matchingPolicy: .nextTimePreservingSmallerComponents) == Self.at("2026-03-29T01:30:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: missing, matchingPolicy: .previousTimePreservingSmallerComponents) == Self.at("2026-03-29T00:30:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: missing, matchingPolicy: .strict) == Self.at("2026-03-30T00:30:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: DateComponents(weekday: 2), matchingPolicy: .nextTime) == Self.at("2026-03-29T22:00:00Z"))
        #expect(calendar.nextDate(after: Self.saturday, matching: DateComponents(), matchingPolicy: .nextTime) == nil)
    }

    @Test func todayAndTheWeekend() {
        defer { TestPlatform.reset() }
        TestPlatform.now = Self.saturday.timeIntervalSince1970
        let calendar = berlin()
        #expect(calendar.isDateInToday(Self.at("2026-03-28T00:00:00Z")))
        #expect(!calendar.isDateInToday(Self.at("2026-03-27T22:00:00Z")))
        #expect(calendar.isDateInYesterday(Self.at("2026-03-27T22:00:00Z")))
        #expect(calendar.isDateInTomorrow(Self.at("2026-03-29T12:00:00Z")))
        #expect(!calendar.isDateInTomorrow(Self.at("2026-03-30T12:00:00Z")))
        #expect(calendar.isDateInWeekend(Self.saturday))
        #expect(!calendar.isDateInWeekend(Self.at("2026-03-30T12:00:00Z")))
    }

    @Test func symbols() {
        let calendar = berlin()
        #expect(calendar.monthSymbols.count == 12)
        #expect(calendar.monthSymbols[2] == "March")
        #expect(calendar.shortMonthSymbols[2] == "Mar")
        #expect(calendar.veryShortMonthSymbols[2] == "M")
        #expect(calendar.standaloneMonthSymbols[2] == "March")
        #expect(calendar.shortStandaloneMonthSymbols[2] == "Mar")
        #expect(calendar.veryShortStandaloneMonthSymbols[2] == "M")
        #expect(calendar.weekdaySymbols.first == "Sunday")
        #expect(calendar.shortWeekdaySymbols.first == "Sun")
        #expect(calendar.veryShortWeekdaySymbols == ["S", "M", "T", "W", "T", "F", "S"])
        #expect(calendar.standaloneWeekdaySymbols[1] == "Monday")
        #expect(calendar.shortStandaloneWeekdaySymbols[1] == "Mon")
        #expect(calendar.veryShortStandaloneWeekdaySymbols.count == 7)
        #expect(calendar.eraSymbols == ["BC", "AD"])
        #expect(calendar.longEraSymbols == ["Before Christ", "Anno Domini"])
        #expect(calendar.amSymbol == "AM")
        #expect(calendar.pmSymbol == "PM")

        let german = berlin(locale: "de_DE")
        #expect(german.weekdaySymbols[1] == "Montag")
        #expect(german.standaloneMonthSymbols[2] == "März")

        // The calendar's locale left to the user's.
        var users = berlin()
        users.locale = nil
        #expect(users.monthSymbols[2] == "March")
    }

    /// The package's own formats count in the package's own arithmetic, and
    /// never ask the platform.
    @Test func thePackagesFormatsStayInThePackage() throws {
        let before = TestPlatform.calls
        let date = Self.at("2026-03-28T12:30:05Z")
        #expect(Date.ISO8601FormatStyle().format(date) == "2026-03-28T12:30:05Z")
        #expect(try Date.ISO8601FormatStyle().parse("2026-03-28T13:30:05+01:00") == date)
        #expect(Date.HTTPFormatStyle().format(date) == "Sat, 28 Mar 2026 12:30:05 GMT")
        #expect(try Date.HTTPFormatStyle().parse("Sat, 28 Mar 2026 12:30:05 GMT") == date)
        #expect(date.description == "2026-03-28 12:30:05 +0000")
        #expect(TestPlatform.calls == before)
    }
}
#endif

#if canImport(Foundation) && !os(Windows)
import Foundation
import Testing
@testable import FoundationEmbedded

/// What the package reads from the C library when it has no platform:
/// the clock (`timespec_get`) and the process's time zone (`localtime_r`).
///
/// Serialized: the tests change the process's `TZ`.
@Suite(.serialized) struct SystemClockAndZoneTests {

    static func at(_ text: String) -> FoundationEmbedded.Date {
        FoundationEmbedded.Date(timeIntervalSince1970: ISO8601DateFormatter().date(from: text)!.timeIntervalSince1970)
    }

    /// Runs `body` with the process in a zone, and puts back what was there.
    func inZone(_ name: String, _ body: () throws -> Void) rethrows {
        let saved = ProcessInfo.processInfo.environment["TZ"]
        setenv("TZ", name, 1)
        tzset()
        defer {
            if let saved {
                setenv("TZ", saved, 1)
            } else {
                unsetenv("TZ")
            }
            tzset()
        }
        try body()
    }

    #if !PlatformHooks

    @Test func theClock() {
        let ours = FoundationEmbedded.Date()
        let theirs = Foundation.Date()
        #expect(abs(ours.timeIntervalSince1970 - theirs.timeIntervalSince1970) < 5)
        #expect(abs(FoundationEmbedded.Date.now.timeIntervalSince1970 - theirs.timeIntervalSince1970) < 5)
        #expect(abs(ours.timeIntervalSinceNow) < 5)
        #expect(FoundationEmbedded.Date(timeIntervalSince1970: 0).timeIntervalSinceNow < -1_000_000_000)
    }

    @Test func theProcessZone() {
        inZone("Europe/Berlin") {
            let zone = FoundationEmbedded.TimeZone.current
            #expect(zone.identifier == "Europe/Berlin", "the TZ variable's value")
            #expect(zone.kind == .system)
            #expect(zone.secondsFromGMT(for: Self.at("2026-01-15T12:00:00Z")) == 3600)
            #expect(zone.secondsFromGMT(for: Self.at("2026-07-01T12:00:00Z")) == 7200)
            #expect(zone.secondsFromGMT(for: Self.at("1965-07-01T12:00:00Z")) == 3600, "before 1970, and before summer time")
            #expect(zone != .gmt)
            #expect(zone.debugDescription == "Europe/Berlin")
            #expect(FoundationEmbedded.Calendar.current.timeZone == zone)
            #expect(FoundationEmbedded.Calendar(identifier: .gregorian).timeZone == zone)
            // The C library has no name to take back.
            #expect(FoundationEmbedded.TimeZone(identifier: "Europe/Berlin") == nil)
        }
        inZone(":Asia/Tokyo") {
            let zone = FoundationEmbedded.TimeZone.current
            #expect(zone.identifier == "Asia/Tokyo")
            #expect(zone.secondsFromGMT(for: Self.at("2026-07-01T12:00:00Z")) == 9 * 3600)
        }
        inZone("") {
            #expect(FoundationEmbedded.TimeZone.current.identifier == "Local")
        }
    }

    /// The package's own arithmetic, in a zone whose clocks change.
    @Test func arithmeticInTheProcessZone() throws {
        try inZone("Europe/Berlin") {
            let calendar = FoundationEmbedded.Calendar.current
            let saturday = Self.at("2026-03-28T12:30:05Z")
            let components = calendar.dateComponents([.year, .month, .day, .hour, .minute, .second, .weekday], from: saturday)
            #expect(components.year == 2026)
            #expect(components.month == 3)
            #expect(components.day == 28)
            #expect(components.hour == 13)
            #expect(components.minute == 30)
            #expect(components.second == 5)
            #expect(components.weekday == 7)
            #expect(calendar.component(.hour, from: Self.at("2026-07-01T12:00:00Z")) == 14)
            #expect(calendar.component(.weekOfYear, from: saturday) == 0, "no week arithmetic of its own")

            #expect(calendar.date(from: DateComponents(year: 2026, month: 3, day: 28, hour: 13, minute: 30, second: 5)) == saturday)
            #expect(calendar.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 14)) == Self.at("2026-07-01T12:00:00Z"))

            // The night the clocks go forward has no 02:30, and the night
            // they go back has two.
            #expect(calendar.date(from: DateComponents(year: 2026, month: 3, day: 29, hour: 2, minute: 30))
                == Self.at("2026-03-29T01:30:00Z"), "03:30, moved later by the gap")
            #expect(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 2, minute: 30))
                == Self.at("2026-10-25T00:30:00Z"), "the first 02:30")
            #expect(calendar.date(from: DateComponents(year: 2026, month: 10, day: 25, hour: 3, minute: 30))
                == Self.at("2026-10-25T02:30:00Z"))

            #expect(calendar.startOfDay(for: saturday) == Self.at("2026-03-27T23:00:00Z"))
            #expect(calendar.startOfDay(for: Self.at("2026-07-01T12:00:00Z")) == Self.at("2026-06-30T22:00:00Z"))
            #expect(calendar.isDate(saturday, inSameDayAs: Self.at("2026-03-28T22:30:00Z")))
            #expect(!calendar.isDate(saturday, inSameDayAs: Self.at("2026-03-28T23:30:00Z")))

            // A day keeps the time on the clock; 24 hours are 24 hours.
            let noon = Self.at("2026-03-28T11:00:00Z")
            #expect(calendar.date(byAdding: .day, value: 1, to: noon) == Self.at("2026-03-29T10:00:00Z"))
            #expect(calendar.date(byAdding: .hour, value: 24, to: noon) == Self.at("2026-03-29T11:00:00Z"))
            #expect(calendar.date(byAdding: .month, value: 1, to: Self.at("2026-01-31T11:00:00Z")) == Self.at("2026-02-28T11:00:00Z"))
            #expect(calendar.date(byAdding: .month, value: 3, to: Self.at("2026-01-31T11:00:00Z")) == Self.at("2026-04-30T10:00:00Z"))
            #expect(calendar.date(byAdding: .weekOfYear, value: 1, to: noon) == nil)

            // As Foundation has them.
            var theirs = Foundation.Calendar(identifier: .gregorian)
            let berlin: Foundation.TimeZone? = Foundation.TimeZone(identifier: "Europe/Berlin")
            theirs.timeZone = try #require(berlin)
            for text in ["2026-03-29T00:59:59Z", "2026-03-29T01:00:00Z", "2026-10-25T00:59:59Z", "2026-10-25T01:00:00Z", "1999-12-31T23:30:00Z"] {
                let date = Self.at(text)
                let foundation = theirs.dateComponents([.year, .month, .day, .hour, .minute], from: Foundation.Date(timeIntervalSince1970: date.timeIntervalSince1970))
                let ours = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                #expect(ours.day == foundation.day, "\(text)")
                #expect(ours.hour == foundation.hour, "\(text)")
                #expect(ours.minute == foundation.minute, "\(text)")
            }
        }
    }

    #endif

    /// The current zone and calendar, whichever build this is: the
    /// process's, or the platform's.
    @Test func currentZoneAndCalendar() {
        let current = FoundationEmbedded.TimeZone.current
        #expect(!current.identifier.isEmpty)
        let offset = current.secondsFromGMT(for: FoundationEmbedded.Date(timeIntervalSince1970: 0))
        #expect(abs(offset) <= 18 * 3600)

        // In the current zone and locale, as Foundation's is.
        let calendar = FoundationEmbedded.Calendar(identifier: .gregorian)
        #expect(calendar.timeZone == current)
        #expect(calendar.locale == FoundationEmbedded.Locale.current)
        #expect(FoundationEmbedded.Calendar.current.timeZone == current)
        #if !PlatformHooks
        #expect(FoundationEmbedded.Calendar.current.identifier == .gregorian)
        #expect(FoundationEmbedded.Calendar.current.firstWeekday == 1)
        #expect(FoundationEmbedded.Calendar.current.minimumDaysInFirstWeek == 1)
        #endif
    }

    /// A fixed zone is the same in every build, whatever the process's is.
    @Test func fixedZonesDontFollowTheProcess() {
        inZone("Asia/Tokyo") {
            let calendar = FoundationEmbedded.Calendar.gmt
            #expect(calendar.component(.hour, from: Self.at("2026-07-01T12:00:00Z")) == 12)
            var plusOne = FoundationEmbedded.Calendar.gmt
            plusOne.timeZone = FoundationEmbedded.TimeZone(secondsFromGMT: 3600)!
            #expect(plusOne.component(.hour, from: Self.at("2026-07-01T12:00:00Z")) == 13)
            #expect(plusOne.date(from: DateComponents(year: 2026, month: 7, day: 1, hour: 13)) == Self.at("2026-07-01T12:00:00Z"))
            // The package's own formats count in GMT.
            #expect(Self.at("2026-07-01T12:00:00Z").description == "2026-07-01 12:00:00 +0000")
        }
    }
}
#endif

#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.Calendar`'s Gregorian math matches
/// `Foundation.Calendar(identifier: .gregorian)` in GMT.
@Suite struct CalendarFoundationParityTests {

    private var foundationCalendar: Foundation.Calendar {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = Foundation.TimeZone(identifier: "GMT")!
        return calendar
    }

    private let cases: [(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int)] = [
        (1970, 1, 1, 0, 0, 0),
        (2001, 1, 1, 0, 0, 0),
        (2000, 2, 29, 12, 30, 15),
        (2024, 6, 15, 14, 25, 45),
        (1999, 12, 31, 23, 59, 59),
        (1900, 3, 1, 6, 0, 0),
        (2100, 7, 4, 18, 45, 30),
    ]

    @Test func dateFromComponentsMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        for c in cases {
            let ours = FoundationEmbedded.DateComponents(
                year: c.year, month: c.month, day: c.day,
                hour: c.hour, minute: c.minute, second: c.second)
            var theirs = Foundation.DateComponents()
            theirs.year = c.year; theirs.month = c.month; theirs.day = c.day
            theirs.hour = c.hour; theirs.minute = c.minute; theirs.second = c.second

            let ourInterval = ourCalendar.timeIntervalSinceReferenceDate(from: ours)
            let theirInterval = foundationCalendar.date(from: theirs)?.timeIntervalSinceReferenceDate
            #expect(ourInterval == theirInterval, "mismatch for \(c)")
        }
    }

    @Test func componentsFromDateMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        let intervals: [Double] = [0, -1, 1, -978307200, 748889145, -2203891200, 4306603530]
        for interval in intervals {
            let ours = ourCalendar.dateComponents(fromTimeIntervalSinceReferenceDate: interval)
            let theirs = foundationCalendar.dateComponents(
                [.era, .year, .month, .day, .hour, .minute, .second, .weekday],
                from: Foundation.Date(timeIntervalSinceReferenceDate: interval))

            #expect(ours.era == theirs.era, "era mismatch @\(interval)")
            #expect(ours.year == theirs.year, "year mismatch @\(interval)")
            #expect(ours.month == theirs.month, "month mismatch @\(interval)")
            #expect(ours.day == theirs.day, "day mismatch @\(interval)")
            #expect(ours.hour == theirs.hour, "hour mismatch @\(interval)")
            #expect(ours.minute == theirs.minute, "minute mismatch @\(interval)")
            #expect(ours.second == theirs.second, "second mismatch @\(interval)")
            #expect(ours.weekday == theirs.weekday, "weekday mismatch @\(interval)")
        }
    }

    @Test func startOfDayMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        let intervals: [Double] = [0, -1, 748889145, 86400.5, -978307200]
        for interval in intervals {
            let ours = ourCalendar.startOfDay(for: .init(timeIntervalSinceReferenceDate: interval))
            let theirs = foundationCalendar.startOfDay(for: .init(timeIntervalSinceReferenceDate: interval))
            #expect(ours.timeIntervalSinceReferenceDate == theirs.timeIntervalSinceReferenceDate,
                "startOfDay mismatch @\(interval)")
        }
    }

    @Test func dateByAddingMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        // (year, month, day) to add, applied to a set of base dates.
        let additions: [(year: Int, month: Int, day: Int)] = [
            (0, 1, 0), (1, 0, 0), (0, 0, 40), (0, -2, 0), (-1, -1, -1), (0, 13, 0), (2, 1, 5),
        ]
        let baseComponents: [(year: Int, month: Int, day: Int)] = [
            (2024, 1, 31), (2024, 2, 29), (2023, 12, 31), (2000, 2, 29), (1999, 1, 15),
        ]
        for base in baseComponents {
            var theirBase = Foundation.DateComponents()
            theirBase.year = base.year; theirBase.month = base.month; theirBase.day = base.day
            let ourBase = ourCalendar.date(from: FoundationEmbedded.DateComponents(
                year: base.year, month: base.month, day: base.day))!
            let theirBaseDate = foundationCalendar.date(from: theirBase)!

            for addition in additions {
                let ourResult = ourCalendar.date(byAdding: FoundationEmbedded.DateComponents(
                    year: addition.year, month: addition.month, day: addition.day), to: ourBase)
                var theirAddition = Foundation.DateComponents()
                theirAddition.year = addition.year; theirAddition.month = addition.month; theirAddition.day = addition.day
                let theirResult = foundationCalendar.date(byAdding: theirAddition, to: theirBaseDate)
                #expect(ourResult?.timeIntervalSinceReferenceDate == theirResult?.timeIntervalSinceReferenceDate,
                    "byAdding \(addition) to \(base) mismatch")
            }
        }
    }

    @Test func rangeOfComponentMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        let baseComponents: [(year: Int, month: Int)] = [(2024, 2), (2023, 2), (2024, 6), (2000, 2), (1900, 2)]
        for base in baseComponents {
            let ourDate = ourCalendar.date(from: FoundationEmbedded.DateComponents(
                year: base.year, month: base.month, day: 10))!
            var theirComponents = Foundation.DateComponents()
            theirComponents.year = base.year; theirComponents.month = base.month; theirComponents.day = 10
            let theirDate = foundationCalendar.date(from: theirComponents)!

            #expect(ourCalendar.range(of: .day, in: .month, for: ourDate)
                == foundationCalendar.range(of: .day, in: .month, for: theirDate), "day-in-month mismatch for \(base)")
            #expect(ourCalendar.range(of: .day, in: .year, for: ourDate)
                == foundationCalendar.range(of: .day, in: .year, for: theirDate), "day-in-year mismatch for \(base)")
            #expect(ourCalendar.range(of: .month, in: .year, for: ourDate)
                == foundationCalendar.range(of: .month, in: .year, for: theirDate), "month-in-year mismatch for \(base)")
        }
    }

    @Test func componentTimeZoneOffsetMatchesFoundation() {
        let ourCalendar = FoundationEmbedded.Calendar.current
        for offset in [3600, -28800, 19800] {
            let ours = FoundationEmbedded.DateComponents(
                year: 2001, month: 1, day: 1, hour: 0, minute: 0, second: 0,
                timeZone: FoundationEmbedded.TimeZone(secondsFromGMT: offset))
            var theirs = Foundation.DateComponents()
            theirs.year = 2001; theirs.month = 1; theirs.day = 1
            theirs.hour = 0; theirs.minute = 0; theirs.second = 0
            theirs.timeZone = Foundation.TimeZone(secondsFromGMT: offset)

            let ourInterval = ourCalendar.timeIntervalSinceReferenceDate(from: ours)
            let theirInterval = foundationCalendar.date(from: theirs)?.timeIntervalSinceReferenceDate
            #expect(ourInterval == theirInterval, "mismatch for offset \(offset)")
        }
    }
}
#endif

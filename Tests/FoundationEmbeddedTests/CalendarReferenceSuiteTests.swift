import Testing
@testable import FoundationEmbedded

/// Reference behavioral suite for the Gregorian `Calendar`, adapted for the
/// embedded subset: GMT only, in-range components only (the reference
/// implementation also normalizes out-of-range components, which this shim
/// does not support). Expected values were generated with the ICU calendar.
@Suite struct CalendarReferenceSuiteTests {

    private let calendar = Calendar.current

    @Test func numberOfDaysInMonth() {
        #expect(Calendar.daysInMonth(year: 2023, month: 2) == 28) // not leap year
        #expect(Calendar.daysInMonth(year: 2024, month: 2) == 29) // leap year
        #expect(Calendar.daysInMonth(year: 2025, month: 2) == 28) // not leap year
        #expect(Calendar.daysInMonth(year: 2028, month: 2) == 29) // leap year
        #expect(Calendar.daysInMonth(year: 2022, month: 12) == 31)
    }

    @Test func dateFromComponents() {
        func test(_ components: DateComponents, expectedTimeIntervalSince1970 expected: Double,
                  sourceLocation: SourceLocation = #_sourceLocation) {
            let date = calendar.date(from: components)
            #expect(date?.timeIntervalSince1970 == expected,
                "date components: \(components)", sourceLocation: sourceLocation)
        }

        test(.init(year: 1705, month: 6, day: 3), expectedTimeIntervalSince1970: -8349350400.0)
        test(.init(year: 1828, month: 7, day: 5), expectedTimeIntervalSince1970: -4465065600.0)
        test(.init(year: 2197, month: 5, day: 1), expectedTimeIntervalSince1970: 7173878400.0)
        test(.init(year: 2443, month: 7, day: 5), expectedTimeIntervalSince1970: 14942448000.0)
        test(.init(year: 2812, month: 5, day: 4), expectedTimeIntervalSince1970: 26581651200.0)
        test(.init(year: 2935, month: 6, day: 3), expectedTimeIntervalSince1970: 30465676800.0)
    }

    @Test func dateComponentsFromDate() {
        func test(timeIntervalSince1970: Double, expectedEra era: Int, year: Int, month: Int, day: Int,
                  hour: Int, minute: Int, second: Int, weekday: Int,
                  sourceLocation: SourceLocation = #_sourceLocation) {
            let date = Date(timeIntervalSince1970: timeIntervalSince1970)
            let dc = calendar.dateComponents([.era, .year, .month, .day, .hour, .minute, .second, .weekday], from: date)
            #expect(dc.era == era, sourceLocation: sourceLocation)
            #expect(dc.year == year, sourceLocation: sourceLocation)
            #expect(dc.month == month, sourceLocation: sourceLocation)
            #expect(dc.day == day, sourceLocation: sourceLocation)
            #expect(dc.hour == hour, sourceLocation: sourceLocation)
            #expect(dc.minute == minute, sourceLocation: sourceLocation)
            #expect(dc.second == second, sourceLocation: sourceLocation)
            #expect(dc.weekday == weekday, sourceLocation: sourceLocation)
        }

        // 1996-12-31T15:23:07Z
        test(timeIntervalSince1970: 852045787.0, expectedEra: 1,
             year: 1996, month: 12, day: 31, hour: 15, minute: 23, second: 7, weekday: 3)
        // 1996-02-29T15:23:07Z
        test(timeIntervalSince1970: 825607387.0, expectedEra: 1,
             year: 1996, month: 2, day: 29, hour: 15, minute: 23, second: 7, weekday: 5)
        // 1996-04-07T01:03:07Z
        test(timeIntervalSince1970: 828838987.0, expectedEra: 1,
             year: 1996, month: 4, day: 7, hour: 1, minute: 3, second: 7, weekday: 1)
        // ICU labels this instant 0001-01-01T01:03:07Z using the hybrid
        // Julian/Gregorian calendar (Julian before October 1582). This shim is
        // proleptic Gregorian, which labels the same instant two days earlier —
        // the same reason `Date.distantPast.description` is 0000-12-30.
        test(timeIntervalSince1970: -62135765813.0, expectedEra: 1,
             year: 0, month: 12, day: 30, hour: 1, minute: 3, second: 7, weekday: 7)
    }
}

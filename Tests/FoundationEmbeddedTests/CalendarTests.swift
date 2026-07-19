import Testing
@testable import FoundationEmbedded

@Suite struct CalendarTests {

    @Test func onlyGregorian() {
        #expect(Calendar.current.identifier == .gregorian)
        #expect(Calendar(identifier: .gregorian).timeZone == .gmt)
    }

    // MARK: - Civil <-> Days

    @Test func daysFromCivilEpoch() {
        #expect(Calendar.daysFromCivil(year: 1970, month: 1, day: 1) == 0)
        // 2001-01-01 is 978307200 seconds after the epoch == 11323 days.
        #expect(Calendar.daysFromCivil(year: 2001, month: 1, day: 1) == 11323)
    }

    @Test func civilFromDaysEpoch() {
        let epoch = Calendar.civilFromDays(0)
        #expect(epoch.year == 1970)
        #expect(epoch.month == 1)
        #expect(epoch.day == 1)
    }

    @Test func civilRoundTrip() {
        for (year, month, day) in [(1970, 1, 1), (2001, 1, 1), (2000, 2, 29), (2024, 12, 31), (1900, 3, 1)] {
            let days = Calendar.daysFromCivil(year: year, month: month, day: day)
            let civil = Calendar.civilFromDays(days)
            #expect(civil.year == year)
            #expect(civil.month == month)
            #expect(civil.day == day)
        }
    }

    @Test func weekday() {
        // 1970-01-01 was a Thursday (5), 2001-01-01 a Monday (2).
        #expect(Calendar.weekday(fromDaysSinceEpoch: 0) == 5)
        #expect(Calendar.weekday(fromDaysSinceEpoch: 11323) == 2)
    }

    // MARK: - Components <-> TimeInterval

    @Test func referenceDateIsZero() {
        let calendar = Calendar.current
        let components = DateComponents(year: 2001, month: 1, day: 1, hour: 0, minute: 0, second: 0)
        #expect(calendar.timeIntervalSinceReferenceDate(from: components) == 0)
    }

    @Test func missingFieldsReturnNil() {
        let calendar = Calendar.current
        #expect(calendar.timeIntervalSinceReferenceDate(from: DateComponents(year: 2001, month: 1)) == nil)
        #expect(calendar.timeIntervalSinceReferenceDate(from: DateComponents()) == nil)
    }

    @Test func componentTimeZoneOffsetApplied() {
        let calendar = Calendar.current
        let plusOne = DateComponents(
            year: 2001, month: 1, day: 1, hour: 0, minute: 0, second: 0,
            timeZone: TimeZone(secondsFromGMT: 3600))
        // Midnight at +01:00 is 23:00 UTC the previous day: one hour before reference.
        #expect(calendar.timeIntervalSinceReferenceDate(from: plusOne) == -3600)
    }

    @Test func decomposeReferenceDate() {
        let calendar = Calendar.current
        let components = calendar.dateComponents(fromTimeIntervalSinceReferenceDate: 0)
        #expect(components.year == 2001)
        #expect(components.month == 1)
        #expect(components.day == 1)
        #expect(components.hour == 0)
        #expect(components.minute == 0)
        #expect(components.second == 0)
        #expect(components.weekday == 2)
    }

    @Test func decomposeNegativeInterval() {
        let calendar = Calendar.current
        // One second before the reference date: 2000-12-31 23:59:59.
        let components = calendar.dateComponents(fromTimeIntervalSinceReferenceDate: -1)
        #expect(components.year == 2000)
        #expect(components.month == 12)
        #expect(components.day == 31)
        #expect(components.hour == 23)
        #expect(components.minute == 59)
        #expect(components.second == 59)
    }

    // MARK: - Date Bridging

    @Test func dateFromComponents() {
        let calendar = Calendar.current
        #expect(calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))?
            .timeIntervalSinceReferenceDate == 0)
        #expect(calendar.date(from: DateComponents(year: 2001, month: 1)) == nil)
    }

    @Test func componentsFromDate() {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSinceReferenceDate: 0))
        #expect(components.year == 2001)
        #expect(components.month == 1)
        #expect(components.day == 1)
    }

    @Test func singleComponentFromDate() {
        let calendar = Calendar.current
        let reference = Date(timeIntervalSinceReferenceDate: 0)
        #expect(calendar.component(.era, from: reference) == 1)
        #expect(calendar.component(.year, from: reference) == 2001)
        #expect(calendar.component(.month, from: reference) == 1)
        #expect(calendar.component(.day, from: reference) == 1)
        #expect(calendar.component(.weekday, from: reference) == 2)
        #expect(calendar.component(.nanosecond, from: reference) == 0)

        let oneHourOneMinuteOneSecond = Date(timeIntervalSinceReferenceDate: 3661)
        #expect(calendar.component(.hour, from: oneHourOneMinuteOneSecond) == 1)
        #expect(calendar.component(.minute, from: oneHourOneMinuteOneSecond) == 1)
        #expect(calendar.component(.second, from: oneHourOneMinuteOneSecond) == 1)
    }

    // MARK: - Calendrical Calculations

    @Test func startOfDay() {
        let calendar = Calendar.current
        let noon = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 12, minute: 30))!
        let midnight = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!
        #expect(calendar.startOfDay(for: noon) == midnight)
        #expect(calendar.startOfDay(for: midnight) == midnight)
    }

    @Test func sameDay() {
        let calendar = Calendar.current
        let morning = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 1))!
        let evening = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15, hour: 23))!
        let nextDay = calendar.date(from: DateComponents(year: 2024, month: 6, day: 16))!
        #expect(calendar.isDate(morning, inSameDayAs: evening))
        #expect(!calendar.isDate(evening, inSameDayAs: nextDay))
    }

    @Test func addingComponents() {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15, hour: 10))!

        let plusMonth = calendar.date(byAdding: DateComponents(month: 1), to: base)
        #expect(calendar.dateComponents([.month], from: plusMonth!).month == 2)

        let plusYearAndDay = calendar.date(byAdding: DateComponents(year: 1, day: 2), to: base)
        let components = calendar.dateComponents([.year, .day], from: plusYearAndDay!)
        #expect(components.year == 2025)
        #expect(components.day == 17)
    }

    @Test func addingClampsDayOfMonth() {
        let calendar = Calendar.current
        let jan31 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!

        let feb = calendar.date(byAdding: .month, value: 1, to: jan31)
        let febComponents = calendar.dateComponents([.month, .day], from: feb!)
        #expect(febComponents.month == 2)
        #expect(febComponents.day == 29)   // 2024 is a leap year

        let nonLeap = calendar.date(byAdding: DateComponents(year: 1, month: 1), to: jan31)
        let nonLeapComponents = calendar.dateComponents([.year, .month, .day], from: nonLeap!)
        #expect(nonLeapComponents.year == 2025)
        #expect(nonLeapComponents.month == 2)
        #expect(nonLeapComponents.day == 28)
    }

    @Test func addingNegativeAndTimeComponents() {
        let calendar = Calendar.current
        let base = calendar.date(from: DateComponents(year: 2024, month: 3, day: 31))!

        let backTwoMonths = calendar.date(byAdding: .month, value: -2, to: base)
        let backComponents = calendar.dateComponents([.year, .month, .day], from: backTwoMonths!)
        #expect(backComponents.month == 1)
        #expect(backComponents.day == 31)

        let plusHour = calendar.date(byAdding: .hour, value: 25, to: base)
        #expect(plusHour == base + 25 * 3600)
        #expect(calendar.date(byAdding: .era, value: 1, to: base) == nil)
    }

    @Test func rangeOfComponents() {
        let calendar = Calendar.current
        let leapFebruary = calendar.date(from: DateComponents(year: 2024, month: 2, day: 10))!
        let plainFebruary = calendar.date(from: DateComponents(year: 2023, month: 2, day: 10))!
        #expect(calendar.range(of: .day, in: .month, for: leapFebruary) == 1..<30)
        #expect(calendar.range(of: .day, in: .month, for: plainFebruary) == 1..<29)
        #expect(calendar.range(of: .day, in: .year, for: leapFebruary) == 1..<367)
        #expect(calendar.range(of: .day, in: .year, for: plainFebruary) == 1..<366)
        #expect(calendar.range(of: .month, in: .year, for: leapFebruary) == 1..<13)
        #expect(calendar.range(of: .hour, in: .day, for: leapFebruary) == nil)
    }

    @Test func componentsRoundTrip() {
        let calendar = Calendar.current
        let original = DateComponents(year: 2024, month: 6, day: 15, hour: 14, minute: 25, second: 45)
        let interval = calendar.timeIntervalSinceReferenceDate(from: original)
        let roundTripped = calendar.dateComponents(fromTimeIntervalSinceReferenceDate: interval!)
        #expect(roundTripped.year == 2024)
        #expect(roundTripped.month == 6)
        #expect(roundTripped.day == 15)
        #expect(roundTripped.hour == 14)
        #expect(roundTripped.minute == 25)
        #expect(roundTripped.second == 45)
    }
}

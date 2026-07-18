import Testing
@testable import FoundationEmbedded

@Suite struct DateComponentsTests {

    @Test func defaultsAreNil() {
        let components = DateComponents()
        #expect(components.year == nil)
        #expect(components.month == nil)
        #expect(components.day == nil)
        #expect(components.hour == nil)
        #expect(components.timeZone == nil)
    }

    @Test func storesValues() {
        let components = DateComponents(year: 2001, month: 1, day: 1, hour: 12, minute: 30, second: 15)
        #expect(components.year == 2001)
        #expect(components.month == 1)
        #expect(components.day == 1)
        #expect(components.hour == 12)
        #expect(components.minute == 30)
        #expect(components.second == 15)
    }

    @Test func equatable() {
        #expect(DateComponents(year: 2001, month: 1) == DateComponents(year: 2001, month: 1))
        #expect(DateComponents(year: 2001, month: 1) != DateComponents(year: 2001, month: 2))
    }

    @Test func description() {
        let components = DateComponents(year: 2001, month: 1, day: 1)
        #expect(components.description == "DateComponents(year: 2001, month: 1, day: 1)")
    }
}

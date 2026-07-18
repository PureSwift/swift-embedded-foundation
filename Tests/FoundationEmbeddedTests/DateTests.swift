import Testing
@testable import FoundationEmbedded

@Suite struct DateTests {

    @Test func referenceAndUnixEpoch() {
        #expect(Date(timeIntervalSinceReferenceDate: 0).timeIntervalSince1970 == 978307200)
        #expect(Date(timeIntervalSince1970: 978307200).timeIntervalSinceReferenceDate == 0)
        #expect(Date(timeIntervalSince1970: 0).timeIntervalSinceReferenceDate == -978307200)
    }

    @Test func arithmetic() {
        let base = Date(timeIntervalSinceReferenceDate: 100)
        #expect(base.addingTimeInterval(50).timeIntervalSinceReferenceDate == 150)

        var mutated = base
        mutated.addTimeInterval(25)
        #expect(mutated.timeIntervalSinceReferenceDate == 125)

        #expect((base + 10).timeIntervalSinceReferenceDate == 110)
        #expect((base - 10).timeIntervalSinceReferenceDate == 90)

        let other = Date(timeIntervalSinceReferenceDate: 30)
        #expect(base - other == 70)
        #expect(base.timeIntervalSince(other) == 70)

        var plus = base
        plus += 5
        #expect(plus.timeIntervalSinceReferenceDate == 105)

        var minus = base
        minus -= 5
        #expect(minus.timeIntervalSinceReferenceDate == 95)
    }

    @Test func comparableAndHashable() {
        let a = Date(timeIntervalSinceReferenceDate: 1)
        let b = Date(timeIntervalSinceReferenceDate: 2)
        #expect(a < b)
        #expect(a == Date(timeIntervalSinceReferenceDate: 1))
        #expect(a != b)
        #expect(a.hashValue == Date(timeIntervalSinceReferenceDate: 1).hashValue)
    }

    @Test func description() {
        let date = Date(timeIntervalSinceReferenceDate: 42)
        #expect(date.description == (42.0).description)
        #expect(date.debugDescription == date.description)
    }
}

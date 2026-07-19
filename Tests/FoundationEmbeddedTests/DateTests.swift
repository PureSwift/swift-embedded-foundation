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

    @Test func epochConstant() {
        #expect(Date.timeIntervalBetween1970AndReferenceDate == 978307200)
    }

    @Test func distantDates() {
        #expect(Date.distantPast < Date(timeIntervalSinceReferenceDate: 0))
        #expect(Date.distantFuture > Date(timeIntervalSinceReferenceDate: 0))
        #expect(Date.distantPast.timeIntervalSinceReferenceDate == -63114076800)
        #expect(Date.distantFuture.timeIntervalSinceReferenceDate == 63113904000)
    }

    @Test func initSinceDate() {
        let base = Date(timeIntervalSinceReferenceDate: 100)
        #expect(Date(timeInterval: 50, since: base).timeIntervalSinceReferenceDate == 150)
        #expect(Date(timeInterval: -50, since: base).timeIntervalSinceReferenceDate == 50)
    }

    @Test func compare() {
        let earlier = Date(timeIntervalSinceReferenceDate: 1)
        let later = Date(timeIntervalSinceReferenceDate: 2)
        #expect(earlier.compare(later) == .orderedAscending)
        #expect(later.compare(earlier) == .orderedDescending)
        #expect(earlier.compare(earlier) == .orderedSame)
    }

    @Test func strideable() {
        let base = Date(timeIntervalSinceReferenceDate: 0)
        #expect(base.distance(to: Date(timeIntervalSinceReferenceDate: 60)) == 60)
        #expect(base.advanced(by: 60).timeIntervalSinceReferenceDate == 60)
        let steps = Array(stride(from: base, to: base + 30, by: 10))
        #expect(steps.count == 3)
    }

    @Test func description() {
        #expect(Date(timeIntervalSinceReferenceDate: 0).description == "2001-01-01 00:00:00 +0000")
        #expect(Date(timeIntervalSinceReferenceDate: -1).description == "2000-12-31 23:59:59 +0000")
        #expect(Date(timeIntervalSince1970: 0).description == "1970-01-01 00:00:00 +0000")
        #expect(Date(timeIntervalSinceReferenceDate: 748889145).description == "2024-09-24 16:45:45 +0000")
        #expect(Date(timeIntervalSinceReferenceDate: .greatestFiniteMagnitude).description == "<description unavailable>")
        let date = Date(timeIntervalSinceReferenceDate: 42)
        #expect(date.debugDescription == date.description)
    }
}

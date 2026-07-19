import Testing
@testable import FoundationEmbedded

@Suite struct DateIntervalTests {

    private func date(_ interval: Double) -> Date {
        Date(timeIntervalSinceReferenceDate: interval)
    }

    @Test func initializers() {
        let interval = DateInterval(start: date(0), end: date(100))
        #expect(interval.duration == 100)
        #expect(interval.end == date(100))

        let fromDuration = DateInterval(start: date(50), duration: 25)
        #expect(fromDuration.end == date(75))
    }

    @Test func endSetter() {
        var interval = DateInterval(start: date(0), duration: 10)
        interval.end = date(30)
        #expect(interval.duration == 30)
    }

    @Test func compareAndOrdering() {
        let a = DateInterval(start: date(0), duration: 10)
        let b = DateInterval(start: date(5), duration: 10)
        let c = DateInterval(start: date(0), duration: 5)
        #expect(a.compare(b) == .orderedAscending)
        #expect(b.compare(a) == .orderedDescending)
        #expect(a.compare(c) == .orderedDescending)   // same start, longer duration
        #expect(a.compare(a) == .orderedSame)
        #expect(c < a)
        #expect(a < b)
    }

    @Test func containsAndIntersection() {
        let a = DateInterval(start: date(0), duration: 100)
        let b = DateInterval(start: date(50), duration: 100)
        let c = DateInterval(start: date(200), duration: 10)

        #expect(a.contains(date(0)))
        #expect(a.contains(date(100)))
        #expect(!a.contains(date(101)))

        #expect(a.intersects(b))
        #expect(!a.intersects(c))

        #expect(a.intersection(with: b) == DateInterval(start: date(50), end: date(100)))
        #expect(a.intersection(with: c) == nil)
        #expect(a.intersection(with: a) == a)
    }

    @Test func equatableAndHashable() {
        let a = DateInterval(start: date(0), duration: 10)
        #expect(a == DateInterval(start: date(0), duration: 10))
        #expect(a != DateInterval(start: date(0), duration: 11))
        #expect(a.hashValue == DateInterval(start: date(0), duration: 10).hashValue)
    }

    @Test func description() {
        let interval = DateInterval(start: date(0), duration: 60)
        #expect(interval.description == "2001-01-01 00:00:00 +0000 to 2001-01-01 00:01:00 +0000")
    }
}

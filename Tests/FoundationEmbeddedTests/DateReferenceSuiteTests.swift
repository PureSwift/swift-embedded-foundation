import Testing
@testable import FoundationEmbedded

/// Reference behavioral suite for `Date`, adapted for the embedded subset:
/// clock-dependent cases use a fixed "now" instead of the current time.
@Suite struct DateReferenceSuiteTests {

    /// Fixed stand-in for the current time: 2024-07-08T02:53:20Z.
    private let now = Date(timeIntervalSinceReferenceDate: 742100000.0)

    @Test func comparison() {
        let d1 = now
        let d2 = d1 + 1

        #expect(d2 > d1)
        #expect(d1 < d2)

        let d3 = Date(timeIntervalSince1970: 12345)
        let d4 = Date(timeIntervalSince1970: 12345)

        #expect(d3 == d4)
        #expect(d3 <= d4)
        #expect(d4 >= d3)
    }

    @Test func mutation() {
        let d0 = now
        var d1 = now
        d1 = d1 + 1.0

        #expect(d1 != d0)

        let d3 = d1
        d1 += 10

        #expect(d1 > d3)
    }

    @Test func distantPast() {
        let distantPast = Date.distantPast
        let currentDate = now

        #expect(distantPast < currentDate)
        #expect(currentDate > distantPast)
        #expect(distantPast.timeIntervalSince(currentDate) <
                          3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    @Test func distantFuture() {
        let distantFuture = Date.distantFuture
        let currentDate = now

        #expect(currentDate < distantFuture)
        #expect(distantFuture > currentDate)
        #expect(distantFuture.timeIntervalSince(currentDate) >
                              3600.0 * 24 * 365 * 100) /* ~1 century in seconds */
    }

    @Test func descriptionReferenceDate() {
        let date = Date(timeIntervalSinceReferenceDate: TimeInterval(0))

        #expect("2001-01-01 00:00:00 +0000" == date.description)
    }

    @Test func description1970() {
        let date = Date(timeIntervalSince1970: TimeInterval(0))

        #expect("1970-01-01 00:00:00 +0000" == date.description)
    }

    @Test func descriptionDistantPast() {
        // Proleptic Gregorian result; the reference date library produces the
        // same string on non-Darwin platforms.
        #expect("0000-12-30 00:00:00 +0000" == Date.distantPast.description)
    }

    @Test func descriptionDistantFuture() {
        #expect("4001-01-01 00:00:00 +0000" == Date.distantFuture.description)
    }

    @Test func descriptionBeyondDistantPast() {
        let date = Date.distantPast.addingTimeInterval(TimeInterval(-1))
        #expect("<description unavailable>" == date.description)
    }

    @Test func descriptionBeyondDistantFuture() {
        let date = Date.distantFuture.addingTimeInterval(TimeInterval(1))
        #expect("<description unavailable>" == date.description)
    }
}

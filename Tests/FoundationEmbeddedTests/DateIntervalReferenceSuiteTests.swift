import Testing
@testable import FoundationEmbedded

/// Reference behavioral suite for `DateInterval`, adapted for the embedded
/// subset. Uses the same fixed dates and expected values as the reference
/// library's suite.
@Suite struct DateIntervalReferenceSuiteTests {

    @Test func compareDateIntervals() {
        // 2010-05-17 14:49:47 -0700
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration: TimeInterval = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)
        #expect(testInterval1 == testInterval2)
        #expect(testInterval2 == testInterval1)
        #expect(testInterval1.compare(testInterval2) == .orderedSame)

        let testInterval3 = DateInterval(start: start, duration: 10000000000.0)
        #expect(testInterval1 < testInterval3)
        #expect(testInterval3 > testInterval1)

        // 2009-05-17 14:49:47 -0700
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        let testInterval4 = DateInterval(start: earlierStart, duration: duration)

        #expect(testInterval4 < testInterval1)
        #expect(testInterval1 > testInterval4)
    }

    @Test func isEqualToDateInterval() {
        // 2010-05-17 14:49:47 -0700
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0
        let testInterval1 = DateInterval(start: start, duration: duration)
        let testInterval2 = DateInterval(start: start, duration: duration)

        #expect(testInterval1 == testInterval2)

        let testInterval3 = DateInterval(start: start, duration: 100.0)
        #expect(testInterval1 != testInterval3)
    }

    @Test func hashing() {
        // 2019-04-04 17:09:23 -0700
        let start1a = Date(timeIntervalSinceReferenceDate: 576115763.0)
        let start1b = Date(timeIntervalSinceReferenceDate: 576115763.0)
        let start2a = Date(timeIntervalSinceReferenceDate: start1a.timeIntervalSinceReferenceDate.nextUp)
        let start2b = Date(timeIntervalSinceReferenceDate: start1a.timeIntervalSinceReferenceDate.nextUp)
        let duration1 = 1800.0
        let duration2 = duration1.nextUp
        // Groups of intervals expected to be equal to each other and unequal
        // to members of every other group.
        let groups: [[DateInterval]] = [
            [
                DateInterval(start: start1a, duration: duration1),
                DateInterval(start: start1b, duration: duration1),
            ],
            [
                DateInterval(start: start1a, duration: duration2),
                DateInterval(start: start1b, duration: duration2),
            ],
            [
                DateInterval(start: start2a, duration: duration1),
                DateInterval(start: start2b, duration: duration1),
            ],
            [
                DateInterval(start: start2a, duration: duration2),
                DateInterval(start: start2b, duration: duration2),
            ],
        ]
        for (groupIndex, group) in groups.enumerated() {
            for member in group {
                #expect(member == group[0])
                #expect(member.hashValue == group[0].hashValue)
            }
            for (otherIndex, otherGroup) in groups.enumerated() where otherIndex != groupIndex {
                #expect(group[0] != otherGroup[0])
            }
        }
    }

    @Test func checkIntersection() {
        // 2010-05-17 14:49:47 -0700 ... 2010-08-17 14:49:47 -0700
        let testInterval1 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 295825787.0),
            end: Date(timeIntervalSinceReferenceDate: 303774587.0))

        // 2010-02-17 14:49:47 -0700 ... 2010-07-17 14:49:47 -0700
        let testInterval2 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 288136187.0),
            end: Date(timeIntervalSinceReferenceDate: 301096187.0))

        #expect(testInterval1.intersects(testInterval2))

        // 2010-10-17 14:49:47 -0700 ... 2010-11-17 14:49:47 -0700
        let testInterval3 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 309044987.0),
            end: Date(timeIntervalSinceReferenceDate: 311723387.0))

        #expect(!testInterval1.intersects(testInterval3))
    }

    @Test func validIntersections() {
        // 2010-05-17 14:49:47 -0700 ... 2010-08-17 14:49:47 -0700
        let testInterval1 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 295825787.0),
            end: Date(timeIntervalSinceReferenceDate: 303774587.0))

        // 2010-02-17 14:49:47 -0700 ... 2010-07-17 14:49:47 -0700
        let testInterval2 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 288136187.0),
            end: Date(timeIntervalSinceReferenceDate: 301096187.0))

        // 2010-05-17 14:49:47 -0700 ... 2010-07-17 14:49:47 -0700
        let testInterval3 = DateInterval(
            start: Date(timeIntervalSinceReferenceDate: 295825787.0),
            end: Date(timeIntervalSinceReferenceDate: 301096187.0))

        let intersection1 = testInterval2.intersection(with: testInterval1)
        #expect(testInterval3 == intersection1)

        let intersection2 = testInterval1.intersection(with: testInterval2)
        #expect(intersection1 == intersection2)
    }

    @Test func containsDate() {
        // 2010-05-17 14:49:47 -0700
        let start = Date(timeIntervalSinceReferenceDate: 295825787.0)
        let duration = 10000000.0

        let testInterval = DateInterval(start: start, duration: duration)
        // 2010-05-17 20:49:47 -0700
        let containedDate = Date(timeIntervalSinceReferenceDate: 295847387.0)

        #expect(testInterval.contains(containedDate))

        // 2009-05-17 14:49:47 -0700
        let earlierStart = Date(timeIntervalSinceReferenceDate: 264289787.0)
        #expect(!testInterval.contains(earlierStart))
    }
}

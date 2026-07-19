#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.DateInterval` behaves like
/// `Foundation.DateInterval` on the subset of API it implements.
@Suite struct DateIntervalFoundationParityTests {

    private let cases: [(startA: Double, durationA: Double, startB: Double, durationB: Double)] = [
        (0, 100, 50, 100),     // overlapping
        (0, 100, 200, 10),     // disjoint
        (0, 100, 100, 50),     // touching at a point
        (0, 100, 25, 50),      // contained
        (0, 10, 0, 10),        // identical
        (0, 10, 0, 5),         // same start, different duration
    ]

    @Test func compareMatchesFoundation() {
        for c in cases {
            let ourResult = FoundationEmbedded.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startA), duration: c.durationA)
                .compare(.init(start: .init(timeIntervalSinceReferenceDate: c.startB), duration: c.durationB))
            let theirResult = Foundation.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startA), duration: c.durationA)
                .compare(.init(start: .init(timeIntervalSinceReferenceDate: c.startB), duration: c.durationB))
            #expect(ourResult.rawValue == theirResult.rawValue, "compare mismatch for \(c)")
        }
    }

    @Test func intersectionMatchesFoundation() {
        for c in cases {
            let ourA = FoundationEmbedded.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startA), duration: c.durationA)
            let ourB = FoundationEmbedded.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startB), duration: c.durationB)
            let theirA = Foundation.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startA), duration: c.durationA)
            let theirB = Foundation.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: c.startB), duration: c.durationB)

            #expect(ourA.intersects(ourB) == theirA.intersects(theirB), "intersects mismatch for \(c)")

            let ourIntersection = ourA.intersection(with: ourB)
            let theirIntersection = theirA.intersection(with: theirB)
            #expect(ourIntersection?.start.timeIntervalSinceReferenceDate
                == theirIntersection?.start.timeIntervalSinceReferenceDate, "start mismatch for \(c)")
            #expect(ourIntersection?.duration == theirIntersection?.duration, "duration mismatch for \(c)")
        }
    }

    @Test func containsMatchesFoundation() {
        let interval = (start: 0.0, duration: 100.0)
        for probe: Double in [-1, 0, 50, 100, 101] {
            let ours = FoundationEmbedded.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: interval.start), duration: interval.duration)
                .contains(.init(timeIntervalSinceReferenceDate: probe))
            let theirs = Foundation.DateInterval(
                start: .init(timeIntervalSinceReferenceDate: interval.start), duration: interval.duration)
                .contains(.init(timeIntervalSinceReferenceDate: probe))
            #expect(ours == theirs, "contains mismatch @\(probe)")
        }
    }
}
#endif

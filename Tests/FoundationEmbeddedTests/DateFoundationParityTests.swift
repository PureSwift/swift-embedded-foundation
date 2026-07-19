#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.Date` behaves like `Foundation.Date` on the
/// subset of API it implements.
@Suite struct DateFoundationParityTests {

    @Test func epochConstantMatchesFoundation() {
        #expect(FoundationEmbedded.Date.timeIntervalBetween1970AndReferenceDate
            == Foundation.Date.timeIntervalBetween1970AndReferenceDate)
    }

    @Test func distantDatesMatchFoundation() {
        #expect(FoundationEmbedded.Date.distantPast.timeIntervalSinceReferenceDate
            == Foundation.Date.distantPast.timeIntervalSinceReferenceDate)
        #expect(FoundationEmbedded.Date.distantFuture.timeIntervalSinceReferenceDate
            == Foundation.Date.distantFuture.timeIntervalSinceReferenceDate)
    }

    @Test func compareMatchesFoundation() {
        let pairs: [(Double, Double)] = [(0, 1), (1, 0), (5, 5), (-10, 10)]
        for (a, b) in pairs {
            let ours = FoundationEmbedded.Date(timeIntervalSinceReferenceDate: a)
                .compare(FoundationEmbedded.Date(timeIntervalSinceReferenceDate: b))
            let theirs = Foundation.Date(timeIntervalSinceReferenceDate: a)
                .compare(Foundation.Date(timeIntervalSinceReferenceDate: b))
            #expect(ours.rawValue == theirs.rawValue)
        }
    }

    @Test func descriptionMatchesFoundation() {
        #if os(Windows)
        // ucrt cannot format dates before 1970, so Foundation's description is
        // "<description unavailable>" there; this shim formats them correctly.
        let intervals: [Double] = [0, -1, 1, -978307200, 748889145, 86400.5]
        #else
        let intervals: [Double] = [0, -1, 1, -978307200, 748889145, 86400.5, -2203891200]
        #endif
        for interval in intervals {
            let ours = FoundationEmbedded.Date(timeIntervalSinceReferenceDate: interval).description
            let theirs = Foundation.Date(timeIntervalSinceReferenceDate: interval).description
            #expect(ours == theirs, "description mismatch @\(interval)")
        }
    }

    @Test func strideMatchesFoundation() {
        let ourDistance = FoundationEmbedded.Date(timeIntervalSinceReferenceDate: 10)
            .distance(to: FoundationEmbedded.Date(timeIntervalSinceReferenceDate: 70))
        let theirDistance = Foundation.Date(timeIntervalSinceReferenceDate: 10)
            .distance(to: Foundation.Date(timeIntervalSinceReferenceDate: 70))
        #expect(ourDistance == theirDistance)
    }
}
#endif

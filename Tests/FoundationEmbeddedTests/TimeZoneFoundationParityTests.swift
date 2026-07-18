#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.TimeZone` behaves like `Foundation.TimeZone` on
/// the subset of API it implements.
@Suite struct TimeZoneFoundationParityTests {

    @Test func gmtMatchesFoundation() {
        #expect(FoundationEmbedded.TimeZone.gmt.identifier == Foundation.TimeZone.gmt.identifier)
        #expect(FoundationEmbedded.TimeZone.gmt.secondsFromGMT == Foundation.TimeZone.gmt.secondsFromGMT())
    }

    @Test func secondsFromGMTInitializerMatchesFoundation() {
        for seconds in [0, 3600, -3600, 19800, -28800, 45900] {
            let ours = FoundationEmbedded.TimeZone(secondsFromGMT: seconds)
            let theirs = Foundation.TimeZone(secondsFromGMT: seconds)
            #expect(ours?.identifier == theirs?.identifier)
            #expect(ours?.secondsFromGMT == theirs?.secondsFromGMT())
        }
    }

    /// Every identifier we accept, Foundation must accept with the same offset.
    /// (Foundation may accept more — that's fine, we are the subset.)
    @Test func acceptedIdentifiersAreASubsetOfFoundation() {
        let identifiers = ["GMT", "UTC", "GMT+05:30", "GMT-0800", "GMT+01", "GMT+0000",
                           "America/New_York", "PST", "not-a-zone"]
        for identifier in identifiers {
            guard let ours = FoundationEmbedded.TimeZone(identifier: identifier) else { continue }
            let theirs = Foundation.TimeZone(identifier: identifier)
            #expect(theirs != nil, "Foundation rejected an identifier we accepted: \(identifier)")
            #expect(ours.secondsFromGMT == theirs?.secondsFromGMT())
        }
    }
}
#endif

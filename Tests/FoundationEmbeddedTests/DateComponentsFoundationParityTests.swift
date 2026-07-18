#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.DateComponents` stores the same fields as
/// `Foundation.DateComponents`. Because every label used here also exists on
/// Foundation's initializer (with a nil default), our surface stays a subset.
@Suite struct DateComponentsFoundationParityTests {

    @Test func fieldsMatchFoundation() {
        let ours = FoundationEmbedded.DateComponents(
            era: 1, year: 2024, month: 6, day: 15,
            hour: 14, minute: 25, second: 45, nanosecond: 500, weekday: 7)
        let theirs = Foundation.DateComponents(
            era: 1, year: 2024, month: 6, day: 15,
            hour: 14, minute: 25, second: 45, nanosecond: 500, weekday: 7)

        #expect(ours.era == theirs.era)
        #expect(ours.year == theirs.year)
        #expect(ours.month == theirs.month)
        #expect(ours.day == theirs.day)
        #expect(ours.hour == theirs.hour)
        #expect(ours.minute == theirs.minute)
        #expect(ours.second == theirs.second)
        #expect(ours.nanosecond == theirs.nanosecond)
        #expect(ours.weekday == theirs.weekday)
    }

    @Test func defaultsMatchFoundation() {
        let ours = FoundationEmbedded.DateComponents()
        let theirs = Foundation.DateComponents()
        #expect(ours.year == theirs.year)   // both nil
        #expect(ours.month == theirs.month)
        #expect(ours.day == theirs.day)
    }
}
#endif

import Testing
@testable import FoundationEmbedded

@Suite struct ComparisonResultTests {

    @Test func rawValues() {
        #expect(ComparisonResult.orderedAscending.rawValue == -1)
        #expect(ComparisonResult.orderedSame.rawValue == 0)
        #expect(ComparisonResult.orderedDescending.rawValue == 1)
        #expect(ComparisonResult(rawValue: -1) == .orderedAscending)
        #expect(ComparisonResult(rawValue: 2) == nil)
    }
}

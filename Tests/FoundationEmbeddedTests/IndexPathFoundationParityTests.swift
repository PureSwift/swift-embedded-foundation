#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.IndexPath` behaves like `Foundation.IndexPath`
/// on the subset of API it implements.
@Suite struct IndexPathFoundationParityTests {

    private let samples: [[Int]] = [
        [], [0], [1], [1, 2], [1, 3], [0, 9], [1, 2, 3], [1, 2, 3, 4], [-1, 5],
    ]

    @Test func compareMatchesFoundation() {
        for left in samples {
            for right in samples {
                let ours = FoundationEmbedded.IndexPath(indexes: left)
                    .compare(FoundationEmbedded.IndexPath(indexes: right))
                let theirs = Foundation.IndexPath(indexes: left)
                    .compare(Foundation.IndexPath(indexes: right))
                #expect(ours.rawValue == theirs.rawValue, "compare mismatch \(left) vs \(right)")
            }
        }
    }

    @Test func orderingMatchesFoundation() {
        let ours = samples.map { FoundationEmbedded.IndexPath(indexes: $0) }.sorted().map(Array.init)
        let theirs = samples.map { Foundation.IndexPath(indexes: $0) }.sorted().map(Array.init)
        #expect(ours == theirs)
    }

    @Test func equalityMatchesFoundation() {
        for left in samples {
            for right in samples {
                let ours = FoundationEmbedded.IndexPath(indexes: left) == FoundationEmbedded.IndexPath(indexes: right)
                let theirs = Foundation.IndexPath(indexes: left) == Foundation.IndexPath(indexes: right)
                #expect(ours == theirs, "equality mismatch \(left) vs \(right)")
            }
        }
    }

    @Test func appendingAndDropLastMatchFoundation() {
        for sample in samples {
            let ours = FoundationEmbedded.IndexPath(indexes: sample)
            let theirs = Foundation.IndexPath(indexes: sample)

            #expect(Array(ours.appending(7)) == Array(theirs.appending(7)),
                "appending element mismatch for \(sample)")
            #expect(Array(ours.appending([8, 9])) == Array(theirs.appending([8, 9])),
                "appending array mismatch for \(sample)")

            // Foundation traps when dropping from an empty path.
            if sample.isEmpty == false {
                #expect(Array(ours.dropLast()) == Array(theirs.dropLast()),
                    "dropLast mismatch for \(sample)")
            }
        }
    }

    @Test func collectionBehaviorMatchesFoundation() {
        for sample in samples {
            let ours = FoundationEmbedded.IndexPath(indexes: sample)
            let theirs = Foundation.IndexPath(indexes: sample)
            #expect(ours.count == theirs.count)
            #expect(Array(ours) == Array(theirs))
            #expect(ours.startIndex == theirs.startIndex)
            #expect(ours.endIndex == theirs.endIndex)
            if sample.count >= 2 {
                #expect(Array(ours[0..<2]) == Array(theirs[0..<2]), "range subscript mismatch for \(sample)")
            }
        }
    }
}
#endif

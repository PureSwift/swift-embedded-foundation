import Testing
@testable import FoundationEmbedded

@Suite struct IndexPathTests {

    // MARK: - Creation

    @Test func initializers() {
        #expect(IndexPath().isEmpty)
        #expect(IndexPath().count == 0)
        #expect(Array(IndexPath(index: 5)) == [5])
        #expect(Array(IndexPath(indexes: [1, 2, 3])) == [1, 2, 3])
        #expect(Array(IndexPath(indexes: (1...3))) == [1, 2, 3])
        let literal: IndexPath = [4, 5, 6]
        #expect(Array(literal) == [4, 5, 6])
    }

    /// Exercises every storage specialization: empty, single, pair, array.
    @Test func storageSpecializations() {
        for count in 0...5 {
            let values = Array(0..<count)
            let path = IndexPath(indexes: values)
            #expect(path.count == count)
            #expect(Array(path) == values)
        }
    }

    // MARK: - Collection

    @Test func collectionAccess() {
        let path = IndexPath(indexes: [10, 20, 30])
        #expect(path.startIndex == 0)
        #expect(path.endIndex == 3)
        #expect(path[0] == 10)
        #expect(path[2] == 30)
        #expect(path.index(after: 0) == 1)
        #expect(path.index(before: 2) == 1)
        #expect(path.first == 10)
        #expect(path.last == 30)
        #expect(Array(path.reversed()) == [30, 20, 10])
    }

    @Test func mutationThroughSubscript() {
        // Each storage case has its own setter path.
        var single = IndexPath(index: 1)
        single[0] = 99
        #expect(Array(single) == [99])

        var pair = IndexPath(indexes: [1, 2])
        pair[0] = 10
        pair[1] = 20
        #expect(Array(pair) == [10, 20])

        var array = IndexPath(indexes: [1, 2, 3])
        array[1] = 20
        #expect(Array(array) == [1, 20, 3])
    }

    @Test func rangeSubscript() {
        let path = IndexPath(indexes: [1, 2, 3, 4])
        #expect(Array(path[1..<3]) == [2, 3])
        #expect(path[0..<0].isEmpty)

        var mutable = path
        mutable[1..<3] = IndexPath(indexes: [9])
        #expect(Array(mutable) == [1, 9, 4])
    }

    // MARK: - Appending and Removing

    @Test func appending() {
        let base = IndexPath(indexes: [1, 2])
        #expect(Array(base.appending(3)) == [1, 2, 3])
        #expect(Array(base.appending(IndexPath(indexes: [3, 4]))) == [1, 2, 3, 4])
        #expect(Array(base.appending([3, 4])) == [1, 2, 3, 4])
        #expect(Array(IndexPath().appending(1)) == [1])
    }

    @Test func operators() {
        let combined = IndexPath(indexes: [1, 2]) + IndexPath(indexes: [3])
        #expect(Array(combined) == [1, 2, 3])

        var mutable = IndexPath(index: 1)
        mutable += IndexPath(indexes: [2, 3])
        #expect(Array(mutable) == [1, 2, 3])
    }

    @Test func dropLast() {
        #expect(Array(IndexPath(indexes: [1, 2, 3]).dropLast()) == [1, 2])
        #expect(Array(IndexPath(index: 1).dropLast()) == [])
        // Dropping from an empty path is allowed and stays empty.
        #expect(IndexPath().dropLast().isEmpty)
    }

    // MARK: - Comparison

    @Test func equality() {
        #expect(IndexPath(indexes: [1, 2]) == IndexPath(indexes: [1, 2]))
        #expect(IndexPath(indexes: [1, 2]) != IndexPath(indexes: [1, 3]))
        #expect(IndexPath(indexes: [1, 2]) != IndexPath(indexes: [1, 2, 3]))
        #expect(IndexPath() == IndexPath())
        // Equal paths hash equally regardless of how they were built.
        #expect(IndexPath(indexes: [1, 2]).hashValue == IndexPath(arrayLiteral: 1, 2).hashValue)
    }

    @Test func compare() {
        #expect(IndexPath(indexes: [1, 2]).compare(IndexPath(indexes: [1, 3])) == .orderedAscending)
        #expect(IndexPath(indexes: [1, 3]).compare(IndexPath(indexes: [1, 2])) == .orderedDescending)
        #expect(IndexPath(indexes: [1, 2]).compare(IndexPath(indexes: [1, 2])) == .orderedSame)
        // A prefix orders before the longer path.
        #expect(IndexPath(indexes: [1]).compare(IndexPath(indexes: [1, 2])) == .orderedAscending)
        #expect(IndexPath(indexes: [1, 2]).compare(IndexPath(indexes: [1])) == .orderedDescending)
        #expect(IndexPath().compare(IndexPath(index: 0)) == .orderedAscending)
    }

    @Test func comparisonOperators() {
        let short = IndexPath(indexes: [1])
        let long = IndexPath(indexes: [1, 2])
        #expect(short < long)
        #expect(short <= long)
        #expect(long > short)
        #expect(long >= short)
        #expect(short <= IndexPath(indexes: [1]))
        #expect(short >= IndexPath(indexes: [1]))
    }

    @Test func sorting() {
        let paths = [
            IndexPath(indexes: [1, 2]),
            IndexPath(indexes: [0, 9]),
            IndexPath(indexes: [1]),
            IndexPath(),
        ]
        #expect(paths.sorted().map(Array.init) == [[], [0, 9], [1], [1, 2]])
    }

    @Test func description() {
        #expect(IndexPath(indexes: [1, 2]).description == "[1, 2]")
        #expect(IndexPath().description == "[]")
        #expect(IndexPath(index: 7).debugDescription == "[7]")
    }
}

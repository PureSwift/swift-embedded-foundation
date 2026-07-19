import Testing
@testable import FoundationEmbedded

@Suite struct DataTests {

    @Test func initializers() {
        #expect(Data().isEmpty)
        #expect(Array(Data([1, 2, 3])) == [1, 2, 3])
        #expect(Array(Data(repeating: 7, count: 3)) == [7, 7, 7])
    }

    @Test func collectionAccess() {
        var data = Data([10, 20, 30])
        #expect(data.startIndex == 0)
        #expect(data.endIndex == 3)
        #expect(data.count == 3)
        #expect(data[1] == 20)
        data[1] = 99
        #expect(data[1] == 99)
        #expect(data.index(after: 0) == 1)
        #expect(data.index(before: 2) == 1)
    }

    @Test func mutation() {
        var data = Data()
        data.append(1)
        data.append(contentsOf: [2, 3])
        data.append(Data([4, 5]))
        #expect(Array(data) == [1, 2, 3, 4, 5])
    }

    @Test func capacity() {
        var data = Data(capacity: 16)
        #expect(data.isEmpty)
        data.reserveCapacity(32)
        data.append(1)
        #expect(Array(data) == [1])
    }

    @Test func subdata() {
        let data = Data([1, 2, 3, 4, 5])
        #expect(Array(data.subdata(in: 1..<4)) == [2, 3, 4])
        #expect(data.subdata(in: 0..<0).isEmpty)
        // Indices of the copy are rebased to zero.
        #expect(data.subdata(in: 3..<5)[0] == 4)
    }

    @Test func equatableAndHashable() {
        #expect(Data([1, 2]) == Data([1, 2]))
        #expect(Data([1, 2]) != Data([1, 3]))
        #expect(Data([1, 2]).hashValue == Data([1, 2]).hashValue)
    }

    @Test func description() {
        #expect(Data([1, 2, 3]).description == "3 bytes")
        #expect(Data([1]).debugDescription == "1 bytes")
    }
}

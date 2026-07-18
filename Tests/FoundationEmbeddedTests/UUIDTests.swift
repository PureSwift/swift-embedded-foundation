import Testing
@testable import FoundationEmbedded

@Suite struct UUIDTests {

    @Test func stringRoundTrip() {
        let string = "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
        #expect(UUID(uuidString: string)?.uuidString == string)
    }

    @Test func fromBytes() {
        let uuid = UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
        #expect(uuid.uuidString == "00010203-0405-0607-0809-0A0B0C0D0E0F")
    }

    @Test func randomHasVersionAndVariant() {
        let uuid = UUID()
        #expect(uuid.uuid.6 & 0xF0 == 0x40)   // version 4
        #expect(uuid.uuid.8 & 0xC0 == 0x80)   // RFC 4122 variant
        #expect(UUID() != UUID())              // vanishingly unlikely to collide
    }

    @Test func invalidStrings() {
        #expect(UUID(uuidString: "") == nil)
        #expect(UUID(uuidString: "not-a-uuid") == nil)
        // Right length, no separators.
        #expect(UUID(uuidString: "E621E1F8C36C495A93FC0C247A3E6E5F0000") == nil)
        // Correct shape, invalid hex digit.
        #expect(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5G") == nil)
    }

    @Test func equatableComparableHashable() {
        let one = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1))
        let two = UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2))
        #expect(one == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)))
        #expect(one != two)
        #expect(one < two)
        #expect(one.hashValue == UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)).hashValue)
    }

    @Test func description() {
        let uuid = UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
        #expect(uuid.description == uuid.uuidString)
        #expect(uuid.debugDescription == uuid.uuidString)
    }
}

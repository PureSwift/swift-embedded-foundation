import Testing
@testable import FoundationEmbedded

/// Reference behavioral suite for `UUID`, adapted for the embedded subset.
@Suite struct UUIDReferenceSuiteTests {

    @Test func equality() {
        let uuidA = UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
        let uuidB = UUID(uuidString: "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        let uuidC = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        let uuidD = UUID()

        #expect(uuidA == uuidB, "String case must not matter.")
        #expect(uuidA == uuidC, "A UUID initialized with a string must be equal to the same UUID initialized with its byte tuple representation.")
        #expect(uuidC != uuidD, "Two different UUIDs must not be equal.")
    }

    @Test func invalidString() {
        let invalid = UUID(uuidString: "Invalid UUID")
        #expect(invalid == nil, "The convenience initializer `init?(uuidString:)` must return nil for an invalid UUID string.")
    }

    @Test func uuidString() {
        let uuid = UUID(uuid: (0xe6, 0x21, 0xe1, 0xf8, 0xc3, 0x6c, 0x49, 0x5a, 0x93, 0xfc, 0x0c, 0x24, 0x7a, 0x3e, 0x6e, 0x5f))
        #expect(uuid.uuidString == "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "The uuidString representation must be uppercase.")
    }

    @Test func description() {
        let uuid = UUID()
        #expect(uuid.description == uuid.uuidString, "The description must be the same as the uuidString.")
    }

    @Test func hash() {
        // This list takes a UUID and tweaks every byte while
        // leaving the version/variant intact.
        let values: [UUID] = [
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a63baa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53caa1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53bab1c-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1d-b4f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b5f5-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f6-48db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-49db-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48dc-9467-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9567-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9468-9786b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9886b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9787b76b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b86b256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76c256c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b266c")!,
            UUID(uuidString: "a53baa1c-b4f5-48db-9467-9786b76b256d")!,
        ]
        // All distinct, and equal values hash equally.
        for (index, value) in values.enumerated() {
            #expect(value == UUID(uuidString: value.uuidString), "round trip must preserve equality")
            #expect(value.hashValue == UUID(uuidString: value.uuidString)!.hashValue)
            for (otherIndex, other) in values.enumerated() where otherIndex != index {
                #expect(value != other)
            }
        }
    }

    @Test func comparable() throws {
        var uuid1 = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000001"))
        var uuid2 = try #require(UUID(uuidString: "00000000-0000-0000-0000-000000000002"))
        #expect(uuid1 < uuid2)
        #expect(uuid2 >= uuid1)
        #expect(uuid2 != uuid1)

        uuid1 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9807CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 < uuid2)
        #expect(uuid2 >= uuid1)
        #expect(uuid2 != uuid1)

        uuid1 = try #require(UUID(uuidString: "9707CE8D-261F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 > uuid2)
        #expect(uuid2 <= uuid1)
        #expect(uuid2 != uuid1)

        uuid1 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        uuid2 = try #require(UUID(uuidString: "9707CE8D-251F-4858-8BF9-C9EC3D690FCE"))
        #expect(uuid1 <= uuid2)
        #expect(uuid2 <= uuid1)
        #expect(uuid2 == uuid1)
    }

    @Test func randomVersionAndVariant() {
        for _ in 0..<100 {
            let uuid = UUID()
            #expect(Int(uuid.uuid.6 >> 4) == 0b0100)
            #expect(Int(uuid.uuid.8 >> 6 & 0b11) == 0b10)
        }
    }
}

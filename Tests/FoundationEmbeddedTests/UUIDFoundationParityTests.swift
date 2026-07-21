#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `UUID` string parsing and formatting match Foundation's `UUID`.
@Suite struct UUIDFoundationParityTests {

    private let byteValues: [FoundationEmbedded.UUID.ByteValue] = [
        (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0),
        (0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF),
        (0xE6, 0x21, 0xE1, 0xF8, 0xC3, 0x6C, 0x49, 0x5A, 0x93, 0xFC, 0x0C, 0x24, 0x7A, 0x3E, 0x6E, 0x5F),
        (0x01, 0x02, 0x03, 0x04, 0x05, 0x06, 0x07, 0x08, 0x09, 0x0A, 0x0B, 0x0C, 0x0D, 0x0E, 0x0F, 0x10),
    ]

    @Test func uuidStringMatchesFoundation() {
        for bytes in byteValues {
            let ours = FoundationEmbedded.UUID(uuid: bytes).uuidString
            let theirs = Foundation.UUID(uuid: bytes).uuidString
            #expect(ours == theirs, "uuidString mismatch for \(bytes)")
        }
    }

    @Test func parseMatchesFoundation() {
        let strings = [
            "E621E1F8-C36C-495A-93FC-0C247A3E6E5F",
            "e621e1f8-c36c-495a-93fc-0c247a3e6e5f",
            "00000000-0000-0000-0000-000000000000",
            "FFFFFFFF-FFFF-FFFF-FFFF-FFFFFFFFFFFF",
        ]
        for string in strings {
            let ours = FoundationEmbedded.UUID(uuidString: string)
            let theirs = Foundation.UUID(uuidString: string)
            #expect(ours?.uuidString == theirs?.uuidString, "parse mismatch for \(string)")
        }
    }

    @Test func parseRejectsWhatFoundationRejects() {
        let strings = [
            "",
            "not-a-uuid",
            "E621E1F8-C36C-495A-93FC-0C247A3E6E5",
            "E621E1F8C36C495A93FC0C247A3E6E5F",
            "E621E1F8-C36C-495A-93FC-0C247A3E6E5G",
        ]
        for string in strings {
            let ours = FoundationEmbedded.UUID(uuidString: string)
            let theirs = Foundation.UUID(uuidString: string)
            #expect((ours == nil) == (theirs == nil), "nil-ness mismatch for \(string)")
        }
    }
}
#endif

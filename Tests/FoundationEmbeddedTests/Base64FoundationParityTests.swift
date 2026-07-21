#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms Base64 encoding and decoding match Foundation's default (no
/// options) behavior.
@Suite struct Base64FoundationParityTests {

    private let byteSequences: [[UInt8]] = [
        [],
        [0],
        [0, 0],
        [0, 0, 0],
        [1, 2, 3, 4, 5],
        Array(0...255),
        [255, 254, 253, 252],
    ]

    @Test func encodeMatchesFoundation() {
        for bytes in byteSequences {
            let ours = FoundationEmbedded.Data(bytes).base64EncodedString()
            let theirs = Foundation.Data(bytes).base64EncodedString()
            #expect(ours == theirs, "encode mismatch for \(bytes)")
        }
    }

    @Test func decodeMatchesFoundation() {
        let strings = [
            "",
            "AA==",
            "AAA=",
            "AAAA",
            "AQIDBAU=",
            "//79/A==",
        ]
        for string in strings {
            let ours = FoundationEmbedded.Data(base64Encoded: string)
            let theirs = Foundation.Data(base64Encoded: string)
            #expect(ours.map(Array.init) == theirs.map(Array.init), "decode mismatch for \(string)")
        }
    }

    @Test func decodeRejectsWhatFoundationRejects() {
        let strings = [
            "A",
            "AAAAA",
            "A===",
            "!!!!",
        ]
        for string in strings {
            let ours = FoundationEmbedded.Data(base64Encoded: string)
            let theirs = Foundation.Data(base64Encoded: string)
            #expect((ours == nil) == (theirs == nil), "nil-ness mismatch for \(string)")
        }
    }

    @Test func roundTripMatchesFoundation() {
        for bytes in byteSequences {
            let ourEncoded = FoundationEmbedded.Data(bytes).base64EncodedString()
            let theirEncoded = Foundation.Data(bytes).base64EncodedString()
            let ourDecoded = FoundationEmbedded.Data(base64Encoded: ourEncoded)
            let theirDecoded = Foundation.Data(base64Encoded: theirEncoded)
            #expect(ourDecoded.map(Array.init) == theirDecoded.map(Array.init),
                "round-trip mismatch for \(bytes)")
        }
    }
}
#endif

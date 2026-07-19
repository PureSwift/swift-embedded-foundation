#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.Data` behaves like `Foundation.Data` on the
/// subset of API it implements.
@Suite struct DataFoundationParityTests {

    @Test func base64EncodingMatchesFoundation() {
        var samples: [[UInt8]] = [[], [0], [255], Array("foobar".utf8), Array(0...255)]
        samples.append((0..<97).map { UInt8(($0 * 37) % 256) })
        for bytes in samples {
            let ours = FoundationEmbedded.Data(bytes).base64EncodedString()
            let theirs = Foundation.Data(bytes).base64EncodedString()
            #expect(ours == theirs, "encode mismatch for \(bytes.count) bytes")
        }
    }

    @Test func base64DecodingMatchesFoundation() {
        // Canonical encodings plus clearly invalid inputs. (Non-canonical but
        // tolerated inputs are excluded: Foundation is lenient about nonzero
        // leftover padding bits, this shim is strict.)
        let inputs = ["", "Zg==", "Zm8=", "Zm9v", "Zm9vYmFy", "AAAA", "////",
                      "Zg=", "Zg!=", "Z===", "@@@@"]
        for input in inputs {
            let ours = FoundationEmbedded.Data(base64Encoded: input).map(Array.init)
            let theirs = Foundation.Data(base64Encoded: input).map(Array.init)
            #expect(ours == theirs, "decode mismatch for \(input)")
        }
    }

    @Test func subdataMatchesFoundation() {
        let bytes: [UInt8] = [10, 20, 30, 40, 50]
        let ours = FoundationEmbedded.Data(bytes).subdata(in: 1..<4)
        let theirs = Foundation.Data(bytes).subdata(in: 1..<4)
        #expect(Array(ours) == Array(theirs))
        #expect(ours.startIndex == theirs.startIndex)   // both rebase to zero
    }
}
#endif

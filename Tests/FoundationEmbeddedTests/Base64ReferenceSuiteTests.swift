import Testing
@testable import FoundationEmbedded

/// Reference behavioral suite for Base64, adapted for the embedded subset:
/// only the default (no-options) encoding and decoding is implemented, so
/// options-based cases (line breaks, URL alphabet, padding omission,
/// unknown-character tolerance) are excluded.
@Suite struct Base64ReferenceSuiteTests {

    @Test func base64Encode_emptyData() {
        #expect(Data().base64EncodedString() == "")
    }

    @Test func base64Encode_arrayOfNulls() {
        let input = Data(repeating: 0, count: 10)
        #expect(input.base64EncodedString() == "AAAAAAAAAAAAAA==")
    }

    @Test func base64Encode_allBytesSequentially() {
        let input = UInt8(0) ... UInt8(255)

        #expect(
            Data(input).base64EncodedString() == """
            AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0B\
            BQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgY\
            KDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw\
            8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w==
            """
        )
    }

    @Test func base64Encode_differentPaddingNeeds() {
        #expect(Data([1, 2, 3, 4]).base64EncodedString() == "AQIDBA==")
        #expect(Data([1, 2, 3, 4, 5]).base64EncodedString() == "AQIDBAU=")
        #expect(Data([1, 2, 3, 4, 5, 6]).base64EncodedString() == "AQIDBAUG")
    }

    @Test func base64Decode_emptyString() {
        #expect(Data() == Data(base64Encoded: ""))
    }

    @Test func base64Decode_arrayOfNulls() {
        #expect(Data(repeating: 0, count: 10) == Data(base64Encoded: "AAAAAAAAAAAAAA=="))
    }

    @Test func base64Decode_AllTheBytesSequentially() {
        let base64 = "AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8gISIjJCUmJygpKissLS4vMDEyMzQ1Njc4OTo7PD0+P0BBQkNERUZHSElKS0xNTk9QUVJTVFVWV1hZWltcXV5fYGFiY2RlZmdoaWprbG1ub3BxcnN0dXZ3eHl6e3x9fn+AgYKDhIWGh4iJiouMjY6PkJGSk5SVlpeYmZqbnJ2en6ChoqOkpaanqKmqq6ytrq+wsbKztLW2t7i5uru8vb6/wMHCw8TFxsfIycrLzM3Oz9DR0tPU1dbX2Nna29zd3t/g4eLj5OXm5+jp6uvs7e7v8PHy8/T19vf4+fr7/P3+/w=="

        #expect(Data(UInt8(0) ... UInt8(255)) == Data(base64Encoded: base64))
    }

    @Test func base64Decode_invalidLength() {
        #expect(Data(base64Encoded: "AAAAA") == nil)
    }

    @Test func base64Decode_variousPaddingNeeds() {
        #expect(Data([1, 2, 3, 4]) == Data(base64Encoded: "AQIDBA=="))
        #expect(Data([1, 2, 3, 4, 5]) == Data(base64Encoded: "AQIDBAU="))
        #expect(Data([1, 2, 3, 4, 5, 6]) == Data(base64Encoded: "AQIDBAUG"))
    }
}

import Testing
@testable import FoundationEmbedded

@Suite struct Base64Tests {

    /// RFC 4648 test vectors.
    private let vectors: [(decoded: String, encoded: String)] = [
        ("", ""),
        ("f", "Zg=="),
        ("fo", "Zm8="),
        ("foo", "Zm9v"),
        ("foob", "Zm9vYg=="),
        ("fooba", "Zm9vYmE="),
        ("foobar", "Zm9vYmFy"),
    ]

    @Test func encode() {
        for vector in vectors {
            #expect(Data(Array(vector.decoded.utf8)).base64EncodedString() == vector.encoded)
        }
    }

    @Test func decode() {
        for vector in vectors {
            let decoded = Data(base64Encoded: vector.encoded)
            #expect(decoded.map { Array($0) } == Array(vector.decoded.utf8))
        }
    }

    @Test func roundTripBinary() {
        let data = Data((0...255).map { UInt8($0) })
        #expect(Data(base64Encoded: data.base64EncodedString()) == data)
    }

    @Test func rejectsInvalid() {
        #expect(Data(base64Encoded: "Zg=") == nil)      // length not a multiple of 4
        #expect(Data(base64Encoded: "Zg!=") == nil)     // non-alphabet character
        #expect(Data(base64Encoded: "Z===") == nil)     // too much padding
        #expect(Data(base64Encoded: "Zg=A") == nil)     // padding before data
        #expect(Data(base64Encoded: "Zh==") == nil)     // nonzero leftover bits
    }
}

//
//  Base64.swift
//  FoundationEmbedded
//
//  Base64 encoding and decoding for the `Data` shim, matching the default
//  (no-options) behavior of Foundation's Base64 API: standard alphabet,
//  `=` padding, strict decoding that rejects any non-alphabet character.
//

extension Data {

    private static let base64Alphabet: [UInt8] = Array(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/".utf8)

    /// Returns a Base-64 encoded string.
    public func base64EncodedString() -> String {
        var output: [UInt8] = []
        output.reserveCapacity((count + 2) / 3 * 4)
        var index = startIndex
        while index < endIndex {
            let byte0 = self[index]
            let byte1 = index + 1 < endIndex ? self[index + 1] : nil
            let byte2 = index + 2 < endIndex ? self[index + 2] : nil

            output.append(Data.base64Alphabet[Int(byte0 >> 2)])
            output.append(Data.base64Alphabet[Int((byte0 & 0x03) << 4 | (byte1 ?? 0) >> 4)])
            if let byte1 {
                output.append(Data.base64Alphabet[Int((byte1 & 0x0F) << 2 | (byte2 ?? 0) >> 6)])
            } else {
                output.append(UInt8(ascii: "="))
            }
            if let byte2 {
                output.append(Data.base64Alphabet[Int(byte2 & 0x3F)])
            } else {
                output.append(UInt8(ascii: "="))
            }
            index += 3
        }
        return String(decoding: output, as: UTF8.self)
    }

    /// Initialize a `Data` from a Base-64 encoded String.
    ///
    /// Returns nil when the input is not recognized as valid Base-64:
    /// the length must be a multiple of 4, padding may only appear at the
    /// end, and no characters outside the standard alphabet are allowed.
    public init?(base64Encoded string: String) {
        let input = Array(string.utf8)
        guard input.count % 4 == 0 else {
            return nil
        }
        var bytes: [UInt8] = []
        bytes.reserveCapacity(input.count / 4 * 3)

        var buffer: UInt32 = 0
        var bitsCollected = 0
        var paddingSeen = 0
        for character in input {
            if character == UInt8(ascii: "=") {
                paddingSeen += 1
                continue
            }
            // Padding must only appear at the end.
            guard paddingSeen == 0, let value = Data.decodeBase64(character) else {
                return nil
            }
            buffer = (buffer << 6) | UInt32(value)
            bitsCollected += 6
            if bitsCollected >= 8 {
                bitsCollected -= 8
                bytes.append(UInt8(truncatingIfNeeded: buffer >> UInt32(bitsCollected)))
            }
        }
        // At most two padding characters, and any leftover bits must be zero.
        switch paddingSeen {
        case 0:
            guard bitsCollected == 0 else { return nil }
        case 1:
            guard bitsCollected == 2, buffer & 0x03 == 0 else { return nil }
        case 2:
            guard bitsCollected == 4, buffer & 0x0F == 0 else { return nil }
        default:
            return nil
        }
        self.init(bytes)
    }

    private static func decodeBase64(_ character: UInt8) -> UInt8? {
        switch character {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"): return character - UInt8(ascii: "A")
        case UInt8(ascii: "a")...UInt8(ascii: "z"): return character - UInt8(ascii: "a") + 26
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return character - UInt8(ascii: "0") + 52
        case UInt8(ascii: "+"): return 62
        case UInt8(ascii: "/"): return 63
        default: return nil
        }
    }
}

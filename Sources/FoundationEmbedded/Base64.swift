//
//  Base64.swift
//  FoundationEmbedded
//
//  Base64 encoding and decoding for the `Data` shim, matching the default
//  (no-options) behavior of Foundation's Base64 API: standard alphabet,
//  `=` padding, strict decoding that rejects any non-alphabet character.
//

extension Data {

    /// The standard Base64 alphabet.
    ///
    /// - Note: A `StaticString` rather than an `[UInt8]` so the table lives in
    ///   constant storage and needs no allocation or reference counting. On a
    ///   bare-metal target a global array would otherwise be heap-allocated on
    ///   first use.
    private static let base64Alphabet = StaticString(
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/")

    /// Returns a Base-64 encoded string.
    public func base64EncodedString() -> String {
        let inputCount = bytes.count
        guard inputCount > 0 else {
            return ""
        }
        
        // Preallocate a buffer for speed.
        let outputCount = (inputCount + 2) / 3 * 4
        let alphabet = Data.base64Alphabet.utf8Start
        let encoded = [UInt8](unsafeUninitializedCapacity: outputCount) { output, initializedCount in
            bytes.withUnsafeBufferPointer { input in
                var read = 0
                var write = 0
                // Whole three-byte groups encode to four characters, no padding.
                while read + 3 <= inputCount {
                    let byte0 = input[read]
                    let byte1 = input[read + 1]
                    let byte2 = input[read + 2]
                    output[write] = alphabet[Int(byte0 >> 2)]
                    output[write + 1] = alphabet[Int((byte0 & 0x03) << 4 | byte1 >> 4)]
                    output[write + 2] = alphabet[Int((byte1 & 0x0F) << 2 | byte2 >> 6)]
                    output[write + 3] = alphabet[Int(byte2 & 0x3F)]
                    read += 3
                    write += 4
                }
                let remaining = inputCount - read
                if remaining > 0 {
                    let byte0 = input[read]
                    let byte1 = remaining > 1 ? input[read + 1] : 0
                    output[write] = alphabet[Int(byte0 >> 2)]
                    output[write + 1] = alphabet[Int((byte0 & 0x03) << 4 | byte1 >> 4)]
                    output[write + 2] = remaining > 1
                        ? alphabet[Int((byte1 & 0x0F) << 2)]
                        : UInt8(ascii: "=")
                    output[write + 3] = UInt8(ascii: "=")
                }
            }
            initializedCount = outputCount
        }
        return String(decoding: encoded, as: UTF8.self)
    }

    /// Initialize a `Data` from a Base-64 encoded String.
    ///
    /// Returns nil when the input is not recognized as valid Base-64:
    /// the length must be a multiple of 4, padding may only appear at the
    /// end, and no characters outside the standard alphabet are allowed.
    public init?(base64Encoded string: String) {
        let utf8 = string.utf8
        guard utf8.count % 4 == 0 else {
            return nil
        }
        
        // Decode using the string's existing contiguous storage for efficiency.
        let decoded = utf8.withContiguousStorageIfAvailable { Data.decodedBytes($0) }
            ?? Array(utf8).withUnsafeBufferPointer { Data.decodedBytes($0) }
        guard let decoded else {
            return nil
        }
        self.init(storage: decoded)
    }

    /// Decodes a whole Base64 quantum-aligned buffer, or `nil` if invalid.
    private static func decodedBytes(_ input: UnsafeBufferPointer<UInt8>) -> [UInt8]? {
        var decoded: [UInt8] = []
        decoded.reserveCapacity(input.count / 4 * 3)

        var buffer: UInt32 = 0
        var bitsCollected = 0
        var paddingSeen = 0
        for character in input {
            if character == UInt8(ascii: "=") {
                paddingSeen += 1
                continue
            }
            // Padding must only appear at the end.
            guard paddingSeen == 0, let value = decodeBase64(character) else {
                return nil
            }
            buffer = (buffer << 6) | UInt32(value)
            bitsCollected += 6
            if bitsCollected >= 8 {
                bitsCollected -= 8
                decoded.append(UInt8(truncatingIfNeeded: buffer >> UInt32(bitsCollected)))
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
        return decoded
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

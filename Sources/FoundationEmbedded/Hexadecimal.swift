//
//  Hexadecimal.swift
//  FoundationEmbedded
//
//  Embedded-safe hexadecimal conversion, adapted from PureSwift/Bluetooth.
//  Strings are built with `String(decoding:as:)` — the same idiom used by the
//  `Decimal` shim — rather than stdlib radix formatting or `[Character]`, both
//  of which are unavailable or unreliable in Embedded Swift.
//

extension FixedWidthInteger {

    /// Uppercase, zero-padded, big-endian hexadecimal representation.
    ///
    /// The result is always `MemoryLayout<Self>.size * 2` characters, e.g. a
    /// `UInt8` yields two characters and a `UInt128` yields 32.
    func toHexadecimal() -> String {
        var value = bigEndian
        var utf8: [UInt8] = []
        utf8.reserveCapacity(MemoryLayout<Self>.size * 2)
        Swift.withUnsafeBytes(of: &value) { buffer in
            for byte in buffer {
                utf8.append(Self.hexNibble(byte >> 4))
                utf8.append(Self.hexNibble(byte & 0x0F))
            }
        }
        return String(decoding: utf8, as: UTF8.self)
    }

    /// Parse a hexadecimal string of exactly `MemoryLayout<Self>.size * 2`
    /// digits (upper- or lowercase). Returns `nil` for any other length or a
    /// non-hex byte.
    init?<S: StringProtocol>(hexadecimal string: S) {
        guard string.utf8.count == MemoryLayout<Self>.size * 2 else {
            return nil
        }
        var result = Self(0)
        for byte in string.utf8 {
            guard let nibble = Self.decodeHexNibble(byte) else {
                return nil
            }
            result = (result << 4) | nibble
        }
        self = result
    }

    /// Map a nibble (0–15) to its uppercase ASCII hex digit.
    private static func hexNibble(_ value: UInt8) -> UInt8 {
        value < 10 ? (0x30 + value) : (0x41 + value - 10) // '0'–'9', 'A'–'F'
    }

    /// Map an ASCII hex digit to its value, or `nil` if it isn't one.
    private static func decodeHexNibble(_ byte: UInt8) -> Self? {
        switch byte {
        case 0x30...0x39: return Self(byte - 0x30)      // '0'–'9'
        case 0x41...0x46: return Self(byte - 0x41 + 10) // 'A'–'F'
        case 0x61...0x66: return Self(byte - 0x61 + 10) // 'a'–'f'
        default: return nil
        }
    }
}

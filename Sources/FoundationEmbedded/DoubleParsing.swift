//
//  DoubleParsing.swift
//  FoundationEmbedded
//
//  Makes floating-point string parsing (`Double`/`Float`/`Float16` from a
//  `String`) work under Embedded Swift.
//
//  The standard library parses floating-point strings by calling C runtime
//  stubs — `_swift_stdlib_strtod_clocale` and its `strtof`/`strtof16`
//  siblings (C-locale `strtod` wrappers that store the value and return the
//  POSIX "end pointer"), succeeding only when the returned pointer is non-null
//  and points at the NUL terminator. Embedded Swift links no runtime stubs, so
//  any use of a float-from-string initializer fails at link time with those
//  symbols (and, on Apple targets, the availability helper
//  `_stdlib_isOSVersionAtLeast`) undefined.
//
//  This file provides a pure Swift C-locale `strtod` and, in Embedded builds
//  only, exports those symbols so the standard library's own initializers link
//  and work. The parser is compiled (and unit-tested) on every platform; the
//  exports never appear in hosted builds, where the real runtime provides them.
//
//  The exports are additionally gated on the `FloatingPointParsingShims`
//  package trait, which is enabled by default. They are required through
//  Swift 6.3, where the stubs are unresolved in Embedded Swift. From Swift 6.4
//  the standard library parses floating-point strings natively in Embedded
//  Swift and no longer references these symbols, so the trait can be disabled
//  — as it should be on any toolchain that provides the stubs itself.
//
//  Accuracy: results are correctly rounded on the common paths — decimal
//  mantissas up to 19 significant digits with exponents reachable exactly
//  (Clinger fast path plus a 128-bit exact-integer path), all hexadecimal
//  floats, infinities, and NaNs. Extreme decimal exponents fall back to
//  stepwise scaling and may differ from the correctly rounded result by a few
//  units in the last place.
//

/// A pure Swift implementation of C-locale `strtod`.
enum StrtodParser {

    /// Parses a `strtod` subject sequence from a NUL-terminated buffer.
    ///
    /// Returns the parsed value and the number of bytes consumed, including
    /// leading whitespace and sign. A `consumed` of 0 means no conversion
    /// (matching C, where `endptr` is set to `nptr`).
    static func parse(_ nptr: UnsafePointer<CChar>) -> (value: Double, consumed: Int) {
        let bytes = UnsafeRawPointer(nptr).assumingMemoryBound(to: UInt8.self)
        var index = 0

        // C-locale whitespace.
        while isSpace(bytes[index]) {
            index += 1
        }

        var negative = false
        switch bytes[index] {
        case UInt8(ascii: "+"):
            index += 1
        case UInt8(ascii: "-"):
            negative = true
            index += 1
        default:
            break
        }

        func signed(_ value: Double) -> Double {
            negative ? -value : value
        }

        // Infinity and NaN keywords (case-insensitive).
        if matches(bytes, at: index, "infinity") {
            return (signed(.infinity), index + 8)
        }
        if matches(bytes, at: index, "inf") {
            return (signed(.infinity), index + 3)
        }
        if matches(bytes, at: index, "nan") {
            var end = index + 3
            // Optional n-char-sequence: "(" [A-Za-z0-9_]* ")". The payload is
            // accepted syntactically but not encoded into the NaN.
            if bytes[end] == UInt8(ascii: "(") {
                var scan = end + 1
                while isAlphanumeric(bytes[scan]) || bytes[scan] == UInt8(ascii: "_") {
                    scan += 1
                }
                if bytes[scan] == UInt8(ascii: ")") {
                    end = scan + 1
                }
            }
            return (signed(.nan), end)
        }

        // Hexadecimal: 0x/0X.
        if bytes[index] == UInt8(ascii: "0"), bytes[index + 1] | 0x20 == UInt8(ascii: "x") {
            if let (value, end) = parseHexadecimal(bytes, mantissaStart: index + 2) {
                return (signed(value), end)
            }
            // "0x" with no hex digits: the subject sequence is just "0".
            return (signed(0), index + 1)
        }

        return parseDecimal(bytes, from: index, negative: negative)
    }

    // MARK: - Decimal

    /// Largest mantissa for which `Double(m)` is exact.
    private static let maxExactMantissa: UInt64 = 1 << 53

    /// Powers of ten that are exactly representable as `Double`.
    private static let exactPowersOfTen: [Double] = [
        1e0, 1e1, 1e2, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9, 1e10, 1e11,
        1e12, 1e13, 1e14, 1e15, 1e16, 1e17, 1e18, 1e19, 1e20, 1e21, 1e22,
    ]

    private static func parseDecimal(
        _ bytes: UnsafePointer<UInt8>, from start: Int, negative: Bool
    ) -> (value: Double, consumed: Int) {
        var index = start
        var mantissa: UInt64 = 0
        var significantDigits = 0
        var exponent = 0
        var droppedNonzero = false
        var sawDigit = false

        // Integer part.
        while let digit = decimalDigit(bytes[index]) {
            sawDigit = true
            if significantDigits < 19 {
                if mantissa != 0 || digit != 0 {
                    mantissa = mantissa * 10 + UInt64(digit)
                    significantDigits += 1
                }
            } else {
                exponent += 1
                droppedNonzero = droppedNonzero || digit != 0
            }
            index += 1
        }

        // Fraction part.
        if bytes[index] == UInt8(ascii: ".") {
            index += 1
            while let digit = decimalDigit(bytes[index]) {
                sawDigit = true
                if significantDigits < 19 {
                    exponent -= 1
                    if mantissa != 0 || digit != 0 {
                        mantissa = mantissa * 10 + UInt64(digit)
                        significantDigits += 1
                    }
                } else {
                    droppedNonzero = droppedNonzero || digit != 0
                }
                index += 1
            }
        }

        guard sawDigit else {
            return (0, 0)   // No conversion.
        }

        // Optional exponent part; not consumed unless it has at least one digit.
        if bytes[index] | 0x20 == UInt8(ascii: "e") {
            var scan = index + 1
            var exponentNegative = false
            if bytes[scan] == UInt8(ascii: "+") {
                scan += 1
            } else if bytes[scan] == UInt8(ascii: "-") {
                exponentNegative = true
                scan += 1
            }
            if decimalDigit(bytes[scan]) != nil {
                var value = 0
                while let digit = decimalDigit(bytes[scan]) {
                    if value < 100_000 {
                        value = value * 10 + digit
                    }
                    scan += 1
                }
                exponent += exponentNegative ? -value : value
                index = scan
            }
        }

        let sign: Double = negative ? -1 : 1
        return (sign * decimalValue(mantissa: mantissa, exponent: exponent, inexact: droppedNonzero), index)
    }

    /// Converts `mantissa * 10^exponent` to the nearest `Double`.
    private static func decimalValue(mantissa: UInt64, exponent: Int, inexact: Bool) -> Double {
        if mantissa == 0 {
            return 0
        }
        // A 19-digit mantissa and |10^308| bound: anything beyond is ±inf / 0.
        if exponent > 310 {
            return .infinity
        }
        if exponent < -350 {
            return 0
        }

        if !inexact, mantissa <= maxExactMantissa {
            // Clinger fast paths: one exactly-rounded operation.
            if exponent >= 0, exponent <= 22 {
                return Double(mantissa) * exactPowersOfTen[exponent]
            }
            if exponent < 0, exponent >= -22 {
                return Double(mantissa) / exactPowersOfTen[-exponent]
            }
            // Move surplus decimal zeros into the mantissa while it stays exact.
            if exponent > 22, exponent <= 22 + 15 {
                var shifted = mantissa
                var overflow = false
                for _ in 0..<(exponent - 22) {
                    let (partial, didOverflow) = shifted.multipliedReportingOverflow(by: 10)
                    if didOverflow || partial > maxExactMantissa {
                        overflow = true
                        break
                    }
                    shifted = partial
                }
                if !overflow {
                    return Double(shifted) * exactPowersOfTen[22]
                }
            }
        }

        if !inexact, exponent >= 0 {
            // Exact-integer path: mantissa * 10^exponent computed in 128 bits,
            // then converted with a single correctly-rounded conversion.
            var product = UInt128(mantissa)
            var remaining = exponent
            var overflow = false
            while remaining > 0 {
                let (partial, didOverflow) = product.multipliedReportingOverflow(by: 10)
                if didOverflow {
                    overflow = true
                    break
                }
                product = partial
                remaining -= 1
            }
            if !overflow {
                return Double(product)
            }
        }

        // Fallback: stepwise scaling by exact powers of ten. Each step rounds
        // once, so extreme exponents can be off by a few ulp.
        var value = Double(mantissa)
        var remaining = exponent
        while remaining > 0 {
            let step = min(remaining, 22)
            value *= exactPowersOfTen[step]
            remaining -= step
        }
        while remaining < 0 {
            let step = min(-remaining, 22)
            value /= exactPowersOfTen[step]
            remaining += step
        }
        return value
    }

    // MARK: - Hexadecimal

    /// Parses the mantissa and binary exponent after `0x`. Returns `nil` when
    /// no hexadecimal digit is present (so the caller can backtrack to `0`).
    private static func parseHexadecimal(
        _ bytes: UnsafePointer<UInt8>, mantissaStart: Int
    ) -> (value: Double, consumed: Int)? {
        var index = mantissaStart
        var mantissa: UInt64 = 0
        var significantDigits = 0
        var binaryExponent = 0
        var sticky = false
        var sawDigit = false

        while let digit = hexDigit(bytes[index]) {
            sawDigit = true
            if significantDigits < 16 {
                if mantissa != 0 || digit != 0 {
                    mantissa = mantissa << 4 | UInt64(digit)
                    significantDigits += 1
                }
            } else {
                binaryExponent += 4
                sticky = sticky || digit != 0
            }
            index += 1
        }
        if bytes[index] == UInt8(ascii: ".") {
            index += 1
            while let digit = hexDigit(bytes[index]) {
                sawDigit = true
                if significantDigits < 16 {
                    binaryExponent -= 4
                    if mantissa != 0 || digit != 0 {
                        mantissa = mantissa << 4 | UInt64(digit)
                        significantDigits += 1
                    }
                } else {
                    sticky = sticky || digit != 0
                }
                index += 1
            }
        }
        guard sawDigit else {
            return nil
        }

        // Optional binary exponent; not consumed unless it has a digit.
        if bytes[index] | 0x20 == UInt8(ascii: "p") {
            var scan = index + 1
            var exponentNegative = false
            if bytes[scan] == UInt8(ascii: "+") {
                scan += 1
            } else if bytes[scan] == UInt8(ascii: "-") {
                exponentNegative = true
                scan += 1
            }
            if decimalDigit(bytes[scan]) != nil {
                var value = 0
                while let digit = decimalDigit(bytes[scan]) {
                    if value < 1_000_000 {
                        value = value * 10 + digit
                    }
                    scan += 1
                }
                binaryExponent += exponentNegative ? -value : value
                index = scan
            }
        }

        if mantissa == 0 {
            return (0, index)
        }
        // Dropped nonzero bits sit far below the rounding bit of the 64→53-bit
        // conversion (the mantissa has 61+ significant bits when digits were
        // dropped), so folding them into the lowest bit preserves rounding.
        if sticky {
            mantissa |= 1
        }
        let value = Double(sign: .plus, exponent: binaryExponent, significand: Double(mantissa))
        return (value, index)
    }

    // MARK: - Character Classes

    private static func isSpace(_ byte: UInt8) -> Bool {
        byte == UInt8(ascii: " ") || (byte >= 0x09 && byte <= 0x0D)
    }

    private static func isAlphanumeric(_ byte: UInt8) -> Bool {
        decimalDigit(byte) != nil || (byte | 0x20) >= UInt8(ascii: "a") && (byte | 0x20) <= UInt8(ascii: "z")
    }

    private static func decimalDigit(_ byte: UInt8) -> Int? {
        byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9") ? Int(byte - UInt8(ascii: "0")) : nil
    }

    private static func hexDigit(_ byte: UInt8) -> Int? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return Int(byte - UInt8(ascii: "0"))
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return Int(byte - UInt8(ascii: "A") + 10)
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return Int(byte - UInt8(ascii: "a") + 10)
        default: return nil
        }
    }

    /// Case-insensitive match of a lowercase ASCII keyword. Stops at the first
    /// mismatch, so it never reads past the NUL terminator.
    private static func matches(_ bytes: UnsafePointer<UInt8>, at index: Int, _ keyword: StaticString) -> Bool {
        var offset = 0
        var result = true
        keyword.withUTF8Buffer { buffer in
            for expected in buffer {
                if bytes[index + offset] | 0x20 != expected {
                    result = false
                    return
                }
                offset += 1
            }
        }
        return result
    }
}

// MARK: - Embedded Runtime Exports

#if hasFeature(Embedded) && FloatingPointParsingShims

/// The C-locale `strtod` the standard library's `Double.init?(_:)` links
/// against. Stores the parsed value and returns the end pointer.
@_cdecl("_swift_stdlib_strtod_clocale")
public func _foundationEmbedded_strtod_clocale(
    _ nptr: UnsafePointer<CChar>?, _ outResult: UnsafeMutablePointer<Double>?
) -> UnsafePointer<CChar>? {
    guard let nptr else {
        return nil
    }
    let (value, consumed) = StrtodParser.parse(nptr)
    outResult?.pointee = value
    return nptr + consumed
}

/// The C-locale `strtof` the standard library's `Float.init?(_:)` links
/// against.
///
/// - Note: Parses at `Double` precision and narrows. This can double-round
///   (differ from a direct `strtof`) only in the rare case where the true
///   value lands near a `Float` rounding boundary that the intermediate
///   `Double` rounds across — not reachable by ordinary decimal literals.
@_cdecl("_swift_stdlib_strtof_clocale")
public func _foundationEmbedded_strtof_clocale(
    _ nptr: UnsafePointer<CChar>?, _ outResult: UnsafeMutablePointer<Float>?
) -> UnsafePointer<CChar>? {
    guard let nptr else {
        return nil
    }
    let (value, consumed) = StrtodParser.parse(nptr)
    outResult?.pointee = Float(value)
    return nptr + consumed
}

/// The C-locale `strtof16` the standard library's `Float16.init?(_:)` links
/// against. The out-parameter is a `__fp16 *`; the value is written as raw
/// `Float16` bits. Narrows from `Double` (see `strtof` note on double-rounding).
@_cdecl("_swift_stdlib_strtof16_clocale")
public func _foundationEmbedded_strtof16_clocale(
    _ nptr: UnsafePointer<CChar>?, _ outResult: UnsafeMutableRawPointer?
) -> UnsafePointer<CChar>? {
    guard let nptr else {
        return nil
    }
    let (value, consumed) = StrtodParser.parse(nptr)
    outResult?.storeBytes(of: Float16(value), as: Float16.self)
    return nptr + consumed
}

/// Availability check referenced by the standard library on Apple embedded
/// targets. There is no OS version to interrogate on bare metal, and the
/// linked standard library is by definition current, so every query passes.
@_cdecl("$es26_stdlib_isOSVersionAtLeastyBi1_Bw_BwBwtF")
public func _foundationEmbedded_isOSVersionAtLeast(_ major: UInt, _ minor: UInt, _ patch: UInt) -> Bool {
    true
}

#endif

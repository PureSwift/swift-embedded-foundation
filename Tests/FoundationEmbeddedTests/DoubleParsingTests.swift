import Testing
@testable import FoundationEmbedded

@Suite struct DoubleParsingTests {

    /// Runs the parser the way the standard library's `Double.init?` does:
    /// success only when the whole string is consumed.
    private func parse(_ string: String) -> Double? {
        string.withCString { pointer in
            let (value, consumed) = StrtodParser.parse(pointer)
            // Matches `Double.init?`: the whole string must be consumed, and an
            // empty subject sequence (nothing consumed) is a failure.
            return consumed > 0 && consumed == string.utf8.count ? value : nil
        }
    }

    private func consumed(_ string: String) -> Int {
        string.withCString { StrtodParser.parse($0).consumed }
    }

    @Test func simpleValues() {
        #expect(parse("0") == 0)
        #expect(parse("1") == 1)
        #expect(parse("1.5") == 1.5)
        #expect(parse("-1.5") == -1.5)
        #expect(parse("+1.5") == 1.5)
        #expect(parse(".5") == 0.5)
        #expect(parse("1.") == 1.0)
        #expect(parse("007") == 7)
        #expect(parse("0.00125") == 0.00125)
    }

    @Test func exponents() {
        #expect(parse("1e10") == 1e10)
        #expect(parse("1E10") == 1e10)
        #expect(parse("2.5e-3") == 2.5e-3)
        #expect(parse("1e+5") == 1e5)
        #expect(parse("1e22") == 1e22)
        #expect(parse("1e-22") == 1e-22)
        #expect(parse("123456789012345678e3") == 123456789012345678e3)   // 128-bit exact path
        #expect(parse("1e30") == 1e30)                                    // Clinger shift path
    }

    @Test func overflowAndUnderflow() {
        #expect(parse("1e999") == .infinity)
        #expect(parse("-1e999") == -.infinity)
        #expect(parse("1e-999") == 0)
        #expect(parse("5e-324") == 5e-324)   // smallest subnormal
    }

    @Test func infinityAndNaN() {
        #expect(parse("inf") == .infinity)
        #expect(parse("INF") == .infinity)
        #expect(parse("-inf") == -.infinity)
        #expect(parse("infinity") == .infinity)
        #expect(parse("Infinity") == .infinity)
        #expect(parse("nan")?.isNaN == true)
        #expect(parse("NaN")?.isNaN == true)
        #expect(parse("nan(0x1)")?.isNaN == true)
    }

    @Test func hexadecimal() {
        #expect(parse("0x10") == 16)
        #expect(parse("0x1.8p1") == 3.0)
        #expect(parse("0xA.8p0") == 10.5)
        #expect(parse("-0x1p-2") == -0.25)
        #expect(parse("0x0p0") == 0)
        #expect(parse("0x.8p1") == 1.0)
    }

    @Test func endPointerSemantics() {
        #expect(consumed("1.5abc") == 3)
        #expect(consumed("  1.5") == 5)      // leading whitespace is consumed
        #expect(consumed("1e") == 1)         // exponent without digits backtracks
        #expect(consumed("1e+") == 1)
        #expect(consumed("0x") == 1)         // subject sequence is just "0"
        #expect(consumed("0xp3") == 1)
        #expect(consumed("e5") == 0)         // no conversion
        #expect(consumed("+") == 0)
        #expect(consumed("") == 0)
        #expect(consumed(".") == 0)
        #expect(consumed("nan(0x1)") == 8)
        #expect(consumed("nan(bad!") == 3)   // unterminated payload backtracks
    }

    @Test func roundTripsShortestDescriptions() {
        let values: [Double] = [
            0, 1, -1, 0.5, 1.5, 0.1, 1.0 / 3.0, .pi, 2.718281828459045,
            12345.6789, 1e15, 9007199254740992, 0.000123456789,
        ]
        for value in values {
            #expect(parse("\(value)") == value, "round trip failed for \(value)")
        }
    }
}

#if canImport(Foundation)
import Foundation

/// Compares the parser against the host's `Double.init?(_:)`, which uses the
/// real C runtime `strtod` path.
@Suite struct DoubleParsingParityTests {

    private func parse(_ string: String) -> Double? {
        string.withCString { pointer in
            let (value, consumed) = StrtodParser.parse(pointer)
            // Matches `Double.init?`: the whole string must be consumed, and an
            // empty subject sequence (nothing consumed) is a failure.
            return consumed > 0 && consumed == string.utf8.count ? value : nil
        }
    }

    @Test func exactParityWithNativeParsing() {
        let strings = [
            "0", "-0", "1", "1.5", "-1.5", "+1.5", ".5", "1.", "007",
            "3.14159265358979", "0.1", "0.3333333333333333",
            "1e10", "2.5e-3", "1e22", "1e-22", "1e30", "123456789012345678e3",
            "1e999", "1e-999", "5e-324",
            "0x10", "0x1.8p1", "0xA.8p0", "0x.8p1",
            "inf", "-inf", "Infinity",
            "1e", "e5", "", ".", "+", "abc", "0x",
        ]
        for string in strings {
            let ours = parse(string)
            let theirs = Double(string)
            #expect(ours?.bitPattern == theirs?.bitPattern,
                "parity mismatch for \(string): \(String(describing: ours)) vs \(String(describing: theirs))")
        }
    }

    /// Narrowing helpers mirroring the `strtof`/`strtof16` exports: parse at
    /// `Double` precision, then narrow.
    private func parseFloat(_ string: String) -> Float? {
        string.withCString { pointer in
            let (value, consumed) = StrtodParser.parse(pointer)
            return consumed > 0 && consumed == string.utf8.count ? Float(value) : nil
        }
    }

    private func parseFloat16(_ string: String) -> Float16? {
        string.withCString { pointer in
            let (value, consumed) = StrtodParser.parse(pointer)
            return consumed > 0 && consumed == string.utf8.count ? Float16(value) : nil
        }
    }

    @Test func floatParityWithNativeParsing() {
        let strings = [
            "1.5", "3.14", "0.1", "0.2", "0.3", "-2.5", "1e10", "2.5e-3", "1.1",
            "123.456", "16777217", "3.4028235e38", "1.4e-45", "9.999999e37",
            "1e40", "1e-50", "0x1.8p1", "inf", "-inf", "nan",
        ]
        for string in strings {
            let ours = parseFloat(string)
            let theirs = Float(string)
            #expect(ours?.bitPattern == theirs?.bitPattern, "Float parity mismatch for \(string)")
        }
    }

    @Test func float16ParityWithNativeParsing() {
        let strings = [
            "1.5", "3.14", "0.1", "65504", "6.1e-5", "0.0001", "2048", "2049",
            "-1.5", "1e10", "1e-10", "inf", "nan",
        ]
        for string in strings {
            let ours = parseFloat16(string)
            let theirs = Float16(string)
            #expect(ours?.bitPattern == theirs?.bitPattern, "Float16 parity mismatch for \(string)")
        }
    }

    @Test func extremeExponentsWithinTolerance() {
        // The stepwise-scaling fallback may be a few ulp from correctly rounded.
        for string in ["1e300", "-2.5e-300", "9.87654321e250", "1.23e-280",
                       "12345678901234567890123e-50", "1.7976931348623157e308"] {
            let ours = parse(string)
            let theirs = Double(string)
            let ourBits = ours!.magnitude.bitPattern
            let theirBits = theirs!.magnitude.bitPattern
            let ulpDistance = ourBits > theirBits ? ourBits - theirBits : theirBits - ourBits
            #expect(ulpDistance <= 4, "\(string): \(ulpDistance) ulp apart")
            #expect((ours! < 0) == (theirs! < 0))
        }
    }
}
#endif

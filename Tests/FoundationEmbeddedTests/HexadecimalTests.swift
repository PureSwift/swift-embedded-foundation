import Testing
@testable import FoundationEmbedded

@Suite struct HexadecimalTests {

    @Test func toHexadecimalWidths() {
        #expect(UInt8(0xAB).toHexadecimal() == "AB")
        #expect(UInt8(0x0F).toHexadecimal() == "0F")
        #expect(UInt8(0).toHexadecimal() == "00")
        #expect(UInt16(0x1234).toHexadecimal() == "1234")
        #expect(UInt16(0x00FF).toHexadecimal() == "00FF")
        #expect(UInt32(0xDEADBEEF).toHexadecimal() == "DEADBEEF")
    }

    @Test func parseUpperAndLowercase() {
        #expect(UInt8(hexadecimal: "AB") == 0xAB)
        #expect(UInt8(hexadecimal: "ab") == 0xAB)
        #expect(UInt16(hexadecimal: "00ff") == 255)
        #expect(UInt32(hexadecimal: "DEADBEEF") == 0xDEADBEEF)
    }

    @Test func rejectsWrongLength() {
        #expect(UInt8(hexadecimal: "A") == nil)     // too short
        #expect(UInt8(hexadecimal: "ABC") == nil)   // too long
        #expect(UInt16(hexadecimal: "FF") == nil)   // needs 4 digits
    }

    @Test func rejectsNonHex() {
        #expect(UInt8(hexadecimal: "ZZ") == nil)
        #expect(UInt8(hexadecimal: "G0") == nil)
        #expect(UInt16(hexadecimal: "12 4") == nil)
    }

    @Test func roundTrip() {
        for value: UInt16 in [0, 1, 255, 256, 0x1234, 0xFFFF] {
            #expect(UInt16(hexadecimal: value.toHexadecimal()) == value)
        }
    }
}

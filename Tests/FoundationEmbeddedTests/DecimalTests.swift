import Testing
@testable import FoundationEmbedded

@Suite struct DecimalTests {

    @Test func normalization() {
        #expect(Decimal(string: "1.2300")?.description == "1.23")
        #expect(Decimal(string: "007")?.description == "7")
        #expect(Decimal(string: "-0")?.description == "0")
        #expect(Decimal(string: "-0.00")?.description == "0")
        #expect(Decimal(string: "-12.50")?.description == "-12.5")
        #expect(Decimal(string: "100")?.description == "100")
        #expect(Decimal(string: "0.5")?.description == "0.5")
    }

    @Test func invalidStrings() {
        #expect(Decimal(string: "") == nil)
        #expect(Decimal(string: "-") == nil)
        #expect(Decimal(string: "1.") == nil)
        #expect(Decimal(string: "abc") == nil)
        #expect(Decimal(string: "1.2.3") == nil)
        #expect(Decimal(string: "1e5") == nil)
        #expect(Decimal(string: ".5") == nil)
    }

    @Test func equatableAndHashable() {
        #expect(Decimal(string: "1.20") == Decimal(string: "1.2"))
        #expect(Decimal(string: "1.2") != Decimal(string: "1.3"))
        #expect(Decimal(string: "1.2")?.hashValue == Decimal(string: "1.20")?.hashValue)
    }

    @Test func description() {
        #expect(Decimal(string: "3.14")?.debugDescription == "3.14")
    }
}

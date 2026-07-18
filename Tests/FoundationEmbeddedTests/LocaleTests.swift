import Testing
@testable import FoundationEmbedded

@Suite struct LocaleTests {

    @Test func currentIsPOSIX() {
        #expect(Locale.current.identifier == "en_US_POSIX")
        #expect(Locale.posix.identifier == "en_US_POSIX")
        #expect(Locale.current == Locale.posix)
    }

    @Test func customIdentifier() {
        let locale = Locale(identifier: "fr_FR")
        #expect(locale.identifier == "fr_FR")
        #expect(locale.description == "fr_FR")
    }

    @Test func equatableAndHashable() {
        #expect(Locale(identifier: "en_US") == Locale(identifier: "en_US"))
        #expect(Locale(identifier: "en_US") != Locale(identifier: "en_GB"))
        #expect(Locale(identifier: "en_US").hashValue == Locale(identifier: "en_US").hashValue)
    }
}

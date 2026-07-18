#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.Locale` behaves like `Foundation.Locale` on the
/// subset of API it implements. Any call written here compiles against both
/// types, which keeps our surface a subset of Foundation's.
@Suite struct LocaleFoundationParityTests {

    @Test func identifierMatchesFoundation() {
        for identifier in ["en_US_POSIX", "en_US", "fr_FR", "de_DE"] {
            let ours = FoundationEmbedded.Locale(identifier: identifier)
            let theirs = Foundation.Locale(identifier: identifier)
            #expect(ours.identifier == theirs.identifier)
        }
    }

    /// `current` intentionally diverges (we return a fixed POSIX locale rather
    /// than a user-configured one), but the value must still be a valid
    /// Foundation locale identifier that round-trips.
    @Test func currentIsValidFoundationIdentifier() {
        let identifier = FoundationEmbedded.Locale.current.identifier
        #expect(Foundation.Locale(identifier: identifier).identifier == identifier)
        #expect(identifier == "en_US_POSIX")
    }
}
#endif

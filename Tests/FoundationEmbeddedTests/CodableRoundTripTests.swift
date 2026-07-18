#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Exercises the `Codable` conformances of every shim by round-tripping through
/// `JSONEncoder`/`JSONDecoder`, including the failure paths that reject invalid
/// encoded values. Values are wrapped in arrays so the top level is valid JSON.
@Suite struct CodableRoundTripTests {

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws -> T {
        let encoded = try JSONEncoder().encode([value])
        return try JSONDecoder().decode([T].self, from: encoded).first!
    }

    @Test func date() throws {
        let value = FoundationEmbedded.Date(timeIntervalSinceReferenceDate: 123.5)
        #expect(try roundTrip(value) == value)
    }

    @Test func data() throws {
        let value = FoundationEmbedded.Data([1, 2, 3, 255])
        #expect(try roundTrip(value) == value)
    }

    @Test func decimal() throws {
        let value = FoundationEmbedded.Decimal(string: "-12.34")!
        #expect(try roundTrip(value) == value)
    }

    @Test func decimalRejectsInvalid() {
        let json = Foundation.Data(#"["1.2.3"]"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([FoundationEmbedded.Decimal].self, from: json)
        }
    }

    @Test func url() throws {
        let value = FoundationEmbedded.URL(string: "https://example.com/path")!
        #expect(try roundTrip(value) == value)
    }

    @Test func urlRejectsEmpty() {
        let json = Foundation.Data(#"[""]"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([FoundationEmbedded.URL].self, from: json)
        }
    }

    @Test func uuid() throws {
        let value = FoundationEmbedded.UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")!
        #expect(try roundTrip(value) == value)
    }

    @Test func uuidRejectsInvalid() {
        let json = Foundation.Data(#"["nope"]"#.utf8)
        #expect(throws: (any Error).self) {
            _ = try JSONDecoder().decode([FoundationEmbedded.UUID].self, from: json)
        }
    }

    @Test func locale() throws {
        let value = FoundationEmbedded.Locale(identifier: "en_US_POSIX")
        #expect(try roundTrip(value) == value)
    }

    @Test func timeZone() throws {
        let value = FoundationEmbedded.TimeZone(secondsFromGMT: 3600)!
        #expect(try roundTrip(value) == value)
    }

    @Test func dateComponents() throws {
        let value = FoundationEmbedded.DateComponents(
            year: 2024, month: 6, day: 15, hour: 12, timeZone: .gmt)
        #expect(try roundTrip(value) == value)
    }

    @Test func calendar() throws {
        let value = FoundationEmbedded.Calendar.current
        let back = try roundTrip(value)
        #expect(back.identifier == value.identifier)
        #expect(back.timeZone == value.timeZone)
        #expect(back.locale == value.locale)
    }
}
#endif

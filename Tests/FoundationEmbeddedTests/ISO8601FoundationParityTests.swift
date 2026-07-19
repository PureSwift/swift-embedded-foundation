#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms ISO 8601 formatting and parsing match `Foundation`'s
/// `Date.ISO8601FormatStyle` across separator and time-zone configurations.
@Suite struct ISO8601FoundationParityTests {

    private let intervals: [Double] = [0, 1718461545, 2147483647, 946684800, 1234567890]

    @Test func formatMatchesFoundation() {
        // (ours, theirs) style pairs with matching configuration.
        let ours = [
            FoundationEmbedded.Date.ISO8601FormatStyle(),
            FoundationEmbedded.Date.ISO8601FormatStyle(dateTimeSeparator: .space),
            FoundationEmbedded.Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted),
            FoundationEmbedded.Date.ISO8601FormatStyle(includingFractionalSeconds: true),
            FoundationEmbedded.Date.ISO8601FormatStyle(timeZone: FoundationEmbedded.TimeZone(secondsFromGMT: 3600)!),
            FoundationEmbedded.Date.ISO8601FormatStyle(
                timeZoneSeparator: .colon,
                timeZone: FoundationEmbedded.TimeZone(secondsFromGMT: -28800)!),
        ]
        let theirs = [
            Foundation.Date.ISO8601FormatStyle(),
            Foundation.Date.ISO8601FormatStyle(dateTimeSeparator: .space),
            Foundation.Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted),
            Foundation.Date.ISO8601FormatStyle(includingFractionalSeconds: true),
            Foundation.Date.ISO8601FormatStyle(timeZone: Foundation.TimeZone(secondsFromGMT: 3600)!),
            Foundation.Date.ISO8601FormatStyle(
                timeZoneSeparator: .colon,
                timeZone: Foundation.TimeZone(secondsFromGMT: -28800)!),
        ]

        for (ourStyle, theirStyle) in zip(ours, theirs) {
            for interval in intervals {
                let ourText = ourStyle.format(FoundationEmbedded.Date(timeIntervalSince1970: interval))
                let theirText = theirStyle.format(Foundation.Date(timeIntervalSince1970: interval))
                #expect(ourText == theirText, "format mismatch @\(interval)")
            }
        }
    }

    @Test func parseMatchesFoundation() throws {
        let ourStyle = FoundationEmbedded.Date.ISO8601FormatStyle()
        let theirStyle = Foundation.Date.ISO8601FormatStyle()

        let valid = [
            "2024-06-15T14:25:45Z",
            "2024-06-15T14:25:45.250Z",
            "2024-06-15T14:25:45+01:00",
            "2024-06-15T14:25:45+0100",
            "2024-06-15T14:25:45-08:00",
            "1970-01-01T00:00:00Z",
            "2038-01-19T03:14:07Z",
        ]
        for string in valid {
            let ours = try ourStyle.parse(string)
            let theirs = try theirStyle.parse(string)
            #expect(ours.timeIntervalSince1970 == theirs.timeIntervalSince1970,
                "parse mismatch for \(string)")
        }
    }

    @Test func rejectsWhatFoundationRejects() {
        let ourStyle = FoundationEmbedded.Date.ISO8601FormatStyle()
        let theirStyle = Foundation.Date.ISO8601FormatStyle()

        // Inputs the reference style rejects with its default separators.
        let invalid = [
            "20240615T142545Z",
            "2024-06-15 14:25:45Z",
            "2024-06-15T14:25:45",
        ]
        for string in invalid {
            #expect((try? theirStyle.parse(string)) == nil, "expected reference to reject \(string)")
            #expect((try? ourStyle.parse(string)) == nil, "expected shim to reject \(string)")
        }
    }
}
#endif

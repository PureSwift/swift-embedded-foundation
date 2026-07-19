#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms the HTTP date format matches Foundation, using Foundation's own
/// Gregorian calendar in GMT as the oracle for the expected field values.
@Suite struct HTTPDateFoundationParityTests {

    private func pad(_ value: Int, _ width: Int) -> String {
        var string = "\(value)"
        while string.count < width {
            string = "0" + string
        }
        return string
    }

    @Test func formatMatchesFoundation() {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = Foundation.TimeZone(identifier: "GMT")!
        let weekdays = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]

        let intervals: [Double] = [0, 784111777, 1_000_000_000, 2_147_483_647, 1_700_000_000]
        for interval in intervals {
            let components = calendar.dateComponents(
                [.weekday, .day, .month, .year, .hour, .minute, .second],
                from: Foundation.Date(timeIntervalSince1970: interval))
            let expected = "\(weekdays[components.weekday! - 1]), "
                + "\(pad(components.day!, 2)) \(months[components.month! - 1]) "
                + "\(pad(components.year!, 4)) "
                + "\(pad(components.hour!, 2)):\(pad(components.minute!, 2)):\(pad(components.second!, 2)) GMT"

            let ours = FoundationEmbedded.Date.HTTPFormatStyle()
                .format(FoundationEmbedded.Date(timeIntervalSince1970: interval))
            #expect(ours == expected, "format mismatch @\(interval)")
        }
    }

    @Test func parseMatchesFoundationComponents() throws {
        var calendar = Foundation.Calendar(identifier: .gregorian)
        calendar.timeZone = Foundation.TimeZone(identifier: "GMT")!

        let strings = [
            "Sun, 06 Nov 1994 08:49:37 GMT",
            "Thu, 01 Jan 1970 00:00:00 GMT",
            "Tue, 19 Jan 2038 03:14:07 GMT",
            "Thu, 29 Feb 2024 23:59:59 GMT",
        ]
        for string in strings {
            let ours = try FoundationEmbedded.Date.HTTPFormatStyle().parse(string)

            // Rebuild the expected instant from the literal fields via Foundation.
            let fields = string.dropFirst(5)   // strip "Xxx, "
            let parts = fields.split(separator: " ")
            let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                          "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
            let time = parts[3].split(separator: ":")
            var components = Foundation.DateComponents()
            components.day = Int(parts[0])
            components.month = months.firstIndex(of: String(parts[1]))! + 1
            components.year = Int(parts[2])
            components.hour = Int(time[0])
            components.minute = Int(time[1])
            components.second = Int(time[2])
            let expected = calendar.date(from: components)!

            #expect(ours.timeIntervalSince1970 == expected.timeIntervalSince1970,
                "parse mismatch for \(string)")
        }
    }
}
#endif

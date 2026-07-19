import Testing
@testable import FoundationEmbedded

@Suite struct HTTPDateTests {

    private let style = Date.HTTPFormatStyle()

    /// The canonical example from RFC 9110 § 5.6.7.
    private let referenceString = "Sun, 06 Nov 1994 08:49:37 GMT"
    /// 1994-11-06T08:49:37Z as seconds since the reference date.
    private var referenceDate: Date {
        Date(timeIntervalSince1970: 784111777)
    }

    // MARK: - Formatting

    @Test func formatsCanonicalExample() {
        #expect(style.format(referenceDate) == referenceString)
    }

    @Test func formatsEpochAndPadding() {
        #expect(style.format(Date(timeIntervalSince1970: 0)) == "Thu, 01 Jan 1970 00:00:00 GMT")
        // Single-digit day, hour, minute and second are zero-padded.
        #expect(style.format(Date(timeIntervalSince1970: 1_000_000_000)) == "Sun, 09 Sep 2001 01:46:40 GMT")
    }

    @Test func formatsEveryMonth() {
        let expected = ["Jan", "Feb", "Mar", "Apr", "May", "Jun",
                        "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let calendar = Calendar(identifier: .gregorian)
        for month in 1...12 {
            let date = calendar.date(from: DateComponents(year: 2024, month: month, day: 15))!
            let formatted = style.format(date)
            #expect(formatted.contains(expected[month - 1]), "month \(month): \(formatted)")
        }
    }

    @Test func formatsEveryWeekday() {
        // 2024-01-07 was a Sunday; seven consecutive days cover every name.
        let expected = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let calendar = Calendar(identifier: .gregorian)
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 7))!
        for offset in 0..<7 {
            let formatted = style.format(start + Double(offset) * 86400)
            #expect(formatted.hasPrefix(expected[offset]), "offset \(offset): \(formatted)")
        }
    }

    // MARK: - Parsing

    @Test func parsesCanonicalExample() throws {
        #expect(try style.parse(referenceString) == referenceDate)
    }

    @Test func parsesWithoutWeekday() throws {
        // The day-name is optional.
        #expect(try style.parse("06 Nov 1994 08:49:37 GMT") == referenceDate)
    }

    @Test func roundTrips() throws {
        let calendar = Calendar(identifier: .gregorian)
        let dates = [
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 784111777),
            calendar.date(from: DateComponents(year: 2024, month: 2, day: 29, hour: 23, minute: 59, second: 59))!,
            calendar.date(from: DateComponents(year: 1999, month: 12, day: 31, hour: 12, minute: 0, second: 0))!,
            calendar.date(from: DateComponents(year: 2038, month: 1, day: 19, hour: 3, minute: 14, second: 7))!,
        ]
        for date in dates {
            #expect(try style.parse(style.format(date)) == date, "round trip failed for \(date)")
        }
    }

    @Test func clampsLeapSecond() throws {
        // Leap seconds are not representable; 60 is clamped to 59.
        let parsed = try style.parse("Sun, 06 Nov 1994 08:49:60 GMT")
        #expect(parsed == Date(timeIntervalSince1970: 784111799))
    }

    @Test func ignoresIncorrectWeekday() throws {
        // The day-name is not cross-checked against the date.
        #expect(try style.parse("Mon, 06 Nov 1994 08:49:37 GMT") == referenceDate)
    }

    @Test func rejectsMalformedInput() {
        let invalid = [
            "",                                  // empty
            "Sun, 06 Nov 1994 08:49:37",         // missing GMT
            "Sun, 06 Nov 1994 08:49:37 UTC",     // wrong zone
            "Sun 06 Nov 1994 08:49:37 GMT",      // missing comma
            "Xyz, 06 Nov 1994 08:49:37 GMT",     // bad weekday name
            "Sun, 06 Xxx 1994 08:49:37 GMT",     // bad month name
            "Sun, 6 Nov 1994 08:49:37 GMT",      // day not zero-padded
            "Sun, 06 Nov 94 08:49:37 GMT",       // two-digit year
            "Sun, 06 Nov 1994 24:49:37 GMT",     // hour out of bounds
            "Sun, 06 Nov 1994 08:60:37 GMT",     // minute out of bounds
            "Sun, 06 Nov 1994 08:49:61 GMT",     // second out of bounds
            "Sun, 06 Nov 1994 08:49:37 GMT ",    // trailing content
            "Sun, 06 Nov 1994 08:49:37 GMTX",    // trailing content
            "Sunday, 06 Nov 1994 08:49:37 GMT",  // RFC 850 form is not accepted
        ]
        for string in invalid {
            #expect(throws: (any Error).self, "should reject: \(string)") {
                _ = try style.parse(string)
            }
        }
    }
}

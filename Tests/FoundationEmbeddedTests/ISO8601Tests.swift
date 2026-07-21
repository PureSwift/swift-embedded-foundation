import Testing
@testable import FoundationEmbedded

@Suite struct ISO8601Tests {

    /// 2024-06-15T14:25:45.25Z
    private let reference = Date(timeIntervalSince1970: 1718461545.25)

    // MARK: - Formatting

    @Test func formatsDefaultStyle() {
        #expect(Date.ISO8601FormatStyle().format(reference) == "2024-06-15T14:25:45Z")
    }

    @Test func formatsFractionalSeconds() {
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        #expect(style.format(reference) == "2024-06-15T14:25:45.250Z")
    }

    @Test func formatsSeparatorVariants() {
        #expect(Date.ISO8601FormatStyle(dateTimeSeparator: .space).format(reference)
            == "2024-06-15 14:25:45Z")
        #expect(Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted).format(reference)
            == "20240615T142545Z")
        // A `Z` designator ignores the time-zone separator.
        #expect(Date.ISO8601FormatStyle(timeZoneSeparator: .colon).format(reference)
            == "2024-06-15T14:25:45Z")
    }

    @Test func formatsTimeZoneOffsets() {
        let plusOne = TimeZone(secondsFromGMT: 3600)!
        #expect(Date.ISO8601FormatStyle(timeZone: plusOne).format(reference)
            == "2024-06-15T15:25:45+0100")
        #expect(Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: plusOne).format(reference)
            == "2024-06-15T15:25:45+01:00")
        let minusEight = TimeZone(secondsFromGMT: -28800)!
        #expect(Date.ISO8601FormatStyle(timeZone: minusEight).format(reference)
            == "2024-06-15T06:25:45-0800")
    }

    @Test func builderMethods() {
        let style = Date.ISO8601FormatStyle()
            .dateSeparator(.omitted)
            .timeSeparator(.omitted)
            .dateTimeSeparator(.space)
        #expect(style.format(reference) == "20240615 142545Z")
        #expect(style.dateSeparator == .omitted)
        #expect(style.timeSeparator == .omitted)
        #expect(style.dateTimeSeparator == .space)
    }

    @Test func fractionalSecondsCarry() {
        // .9996 rounds up to a whole second and carries.
        let style = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        let date = Date(timeIntervalSince1970: 1718461545.9996)
        #expect(style.format(date) == "2024-06-15T14:25:46.000Z")
    }

    // MARK: - Parsing

    @Test func parsesDefaultStyle() throws {
        let style = Date.ISO8601FormatStyle()
        #expect(try style.parse("2024-06-15T14:25:45Z").timeIntervalSince1970 == 1718461545)
    }

    @Test func parsesFractionalSeconds() throws {
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        #expect(try fractional.parse("2024-06-15T14:25:45.250Z").timeIntervalSince1970 == 1718461545.25)
        #expect(try fractional.parse("2024-06-15T14:25:45.5Z").timeIntervalSince1970 == 1718461545.5)
    }

    @Test func fractionalSecondsAreOptionalRegardlessOfStyle() throws {
        // Matches the reference implementation: fractional seconds are
        // accepted whether or not they are present, regardless of
        // `includingFractionalSeconds`.
        let plain = Date.ISO8601FormatStyle()
        let fractional = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
        #expect(try plain.parse("2024-06-15T14:25:45.250Z").timeIntervalSince1970 == 1718461545.25)
        #expect(try fractional.parse("2024-06-15T14:25:45Z").timeIntervalSince1970 == 1718461545)
    }

    @Test func parsesNumericOffsets() throws {
        let style = Date.ISO8601FormatStyle()
        // Both offset spellings are accepted regardless of timeZoneSeparator.
        #expect(try style.parse("2024-06-15T14:25:45+01:00").timeIntervalSince1970 == 1718457945)
        #expect(try style.parse("2024-06-15T14:25:45+0100").timeIntervalSince1970 == 1718457945)
        #expect(try style.parse("2024-06-15T14:25:45-08:00").timeIntervalSince1970 == 1718490345)
        #expect(try style.parse("2024-06-15T14:25:45z").timeIntervalSince1970 == 1718461545)
    }

    @Test func parseRespectsConfiguredSeparators() throws {
        let compact = Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted)
        #expect(try compact.parse("20240615T142545Z").timeIntervalSince1970 == 1718461545)
        // The compact style rejects the extended form, and vice versa.
        #expect(throws: ISO8601ParseError.self) { _ = try compact.parse("2024-06-15T14:25:45Z") }
        #expect(throws: ISO8601ParseError.self) {
            _ = try Date.ISO8601FormatStyle().parse("20240615T142545Z")
        }
    }

    @Test func roundTrips() throws {
        let styles = [
            Date.ISO8601FormatStyle(),
            Date.ISO8601FormatStyle(includingFractionalSeconds: true),
            Date.ISO8601FormatStyle(dateSeparator: .omitted, timeSeparator: .omitted),
            Date.ISO8601FormatStyle(dateTimeSeparator: .space),
            Date.ISO8601FormatStyle(timeZone: TimeZone(secondsFromGMT: 3600)!),
            Date.ISO8601FormatStyle(timeZoneSeparator: .colon, timeZone: TimeZone(secondsFromGMT: -19800)!),
        ]
        let dates = [
            Date(timeIntervalSince1970: 0),
            Date(timeIntervalSince1970: 1718461545),
            Date(timeIntervalSince1970: 2147483647),
        ]
        for style in styles {
            for date in dates {
                let parsed = try style.parse(style.format(date))
                #expect(parsed == date, "round trip failed for \(style.format(date))")
            }
        }
    }

    @Test func rejectsMalformedInput() {
        let style = Date.ISO8601FormatStyle()
        let invalid = [
            "",
            "2024-06-15T14:25:45",            // missing time zone
            "2024-06-15 14:25:45Z",           // wrong date/time separator
            "2024-06-15T14:25:45Q",           // bad zone designator
            "2024-06-15T24:25:45Z",           // hour out of bounds
            "2024-06-15T14:60:45Z",           // minute out of bounds
            "2024-06-15T14:25:61Z",           // second out of bounds
            "2024-06-15T14:25:45.Z",          // empty fraction
            "2024-06-15T14:25:45+01:60",      // offset minutes out of bounds
            "2024-06-15T14:25:45Z ",          // trailing content
            "24-06-15T14:25:45Z",             // two-digit year
        ]
        for string in invalid {
            #expect(throws: ISO8601ParseError.self, "should reject: \(string)") {
                _ = try style.parse(string)
            }
        }
    }

    @Test func clampsLeapSecond() throws {
        let style = Date.ISO8601FormatStyle()
        #expect(try style.parse("2016-12-31T23:59:60Z").timeIntervalSince1970
            == style.parse("2016-12-31T23:59:59Z").timeIntervalSince1970)
    }
}

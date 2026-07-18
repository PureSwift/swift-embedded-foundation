import Testing
@testable import FoundationEmbedded

@Suite struct TimeZoneTests {

    @Test func gmtAndCurrent() {
        #expect(TimeZone.gmt.secondsFromGMT == 0)
        #expect(TimeZone.gmt.identifier == "GMT")
        #expect(TimeZone.current == TimeZone.gmt)
    }

    @Test func identifierGMTAndUTC() {
        #expect(TimeZone(identifier: "GMT")?.secondsFromGMT == 0)
        #expect(TimeZone(identifier: "UTC")?.secondsFromGMT == 0)
    }

    @Test func identifierWithColonOffset() {
        #expect(TimeZone(identifier: "GMT+05:30")?.secondsFromGMT == 19800)
        #expect(TimeZone(identifier: "GMT-08:00")?.secondsFromGMT == -28800)
    }

    @Test func identifierWithCompactOffset() {
        #expect(TimeZone(identifier: "GMT-0800")?.secondsFromGMT == -28800)
        #expect(TimeZone(identifier: "GMT+01")?.secondsFromGMT == 3600)
    }

    @Test func invalidIdentifiers() {
        #expect(TimeZone(identifier: "America/New_York") == nil)
        #expect(TimeZone(identifier: "GMT+99:99") == nil)
        #expect(TimeZone(identifier: "PST") == nil)
    }

    @Test func secondsFromGMTInitializer() {
        let zone = TimeZone(secondsFromGMT: 3600)
        #expect(zone?.secondsFromGMT == 3600)
        #expect(zone?.identifier == "GMT+01:00")
        #expect(TimeZone(secondsFromGMT: 0)?.identifier == "GMT")
        #expect(TimeZone(secondsFromGMT: -19 * 3600) == nil)
    }
}

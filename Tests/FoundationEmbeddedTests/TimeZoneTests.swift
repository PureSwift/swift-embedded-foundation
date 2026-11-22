import Testing
@testable import FoundationEmbedded

@Suite struct TimeZoneTests {

    @Test func gmtAndCurrent() {
        #expect(TimeZone.gmt.secondsFromGMT == 0)
        #expect(TimeZone.gmt.identifier == "GMT")
        // The process's zone, or the platform's: whichever, it answers
        // for itself, and a fixed zone keeps its offset.
        let current = TimeZone.current
        #expect(!current.identifier.isEmpty)
        let offset = current.secondsFromGMT(for: Date(timeIntervalSince1970: 0))
        #expect(abs(offset) <= 18 * 3600)
        #expect(TimeZone.gmt.secondsFromGMT(for: Date(timeIntervalSince1970: 1_782_907_200)) == 0)
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

    @Test func secondsFromGMTForDate() {
        // Fixed offset, so the date argument is ignored.
        #expect(TimeZone.gmt.secondsFromGMT(for: Date(timeIntervalSinceReferenceDate: 0)) == 0)
        #expect(TimeZone(secondsFromGMT: 3600)?.secondsFromGMT(for: Date(timeIntervalSinceReferenceDate: 5)) == 3600)
    }

    @Test func invalidIdentifiers() {
        #expect(TimeZone(identifier: "GMT+99:99") == nil)
        #expect(TimeZone(identifier: "Mars/Olympus") == nil)
        #if !PlatformHooks
        // By itself the package has no zone database.
        #expect(TimeZone(identifier: "America/New_York") == nil)
        #expect(TimeZone(identifier: "PST") == nil)
        #endif
    }

    @Test func secondsFromGMTInitializer() {
        let zone = TimeZone(secondsFromGMT: 3600)
        #expect(zone?.secondsFromGMT == 3600)
        #expect(zone?.identifier == "GMT+0100")
        #expect(TimeZone(secondsFromGMT: 0)?.identifier == "GMT")
        #expect(TimeZone(secondsFromGMT: -19 * 3600) == nil)
    }
}

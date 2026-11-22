@testable import FoundationEmbedded

extension FoundationEmbedded.Calendar {

    /// The Gregorian calendar in GMT, which every build of the package
    /// answers for alike. `current` is in the process's time zone, or the
    /// user's with the `PlatformHooks` trait, so a test of the arithmetic
    /// names its zone.
    static var gmt: FoundationEmbedded.Calendar {
        var calendar = FoundationEmbedded.Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        return calendar
    }
}

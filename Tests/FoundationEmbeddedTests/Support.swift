@testable import FoundationEmbedded

extension FoundationEmbedded.Calendar {

    /// The Gregorian calendar in GMT, which every build of the package
    /// answers for alike. `current` is in the process's time zone, or the
    /// user's with the `PlatformHooks` trait, so a test of the arithmetic
    /// names its zone.
    ///
    /// It is made without asking for the current zone. One suite changes
    /// the process's `TZ`, and the C library's environment isn't safe to
    /// read from another thread meanwhile; only that suite asks.
    static var gmt: FoundationEmbedded.Calendar {
        FoundationEmbedded.Calendar(gregorianIn: .gmt)
    }
}

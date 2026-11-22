# FoundationEmbedded

Foundation value types for Embedded Swift.

A dependency-free reimplementation of a subset of Foundation's value types that
compiles and runs under Embedded Swift — including bare-metal targets like
Cortex-M and RISC-V — while remaining buildable on every hosted platform
(macOS, Linux, Windows, Android).

## Design

- **Strict API subset.** Every public declaration mirrors Foundation's API, so
  code written against this package compiles unchanged against Foundation.
  Behavioral parity is enforced by tests that run the same operations through
  both implementations.
- **Compiles anywhere.** No `canImport(Foundation)` gating inside the package;
  the *consumer* decides when to use these types instead of Foundation's.
- **No I/O, no zone database, no locale database.** API that requires a file
  system or ICU data is deliberately omitted. The clock and the process's
  time zone are read from the C library where there is one. Everything else
  a platform knows — the user's settings, time zones by name, calendars other
  than the Gregorian — comes from the platform, through the
  [`PlatformHooks`](#platformhooks) trait, or not at all.

## Coverage

| Type | Supported | Not supported |
|---|---|---|
| `Date` | intervals since reference/1970 epochs, arithmetic, comparison, `distantPast`/`distantFuture`, `Strideable`, UTC `description`; `init()`, `now` and `timeIntervalSinceNow` from C11's `timespec_get` | a clock on bare metal with no C library, without `PlatformHooks` |
| `DateInterval` | intervals, `contains`, `intersects`, `intersection`, comparison | clock-based `init()` |
| `DateComponents` | calendar, era, year, month, day, hour, minute, second, nanosecond, weekday, weekdayOrdinal, weekOfMonth, weekOfYear, yearForWeekOfYear, dayOfYear, isLeapMonth, timeZone, `value(for:)`, `setValue(_:for:)`, `date` | quarter |
| `Calendar` | Gregorian: components ↔ dates, `startOfDay`, `isDate(inSameDayAs:)`, `date(byAdding:)` with day clamping, `range(of:in:)`, in a fixed offset or the process's zone, where a missing wall-clock time moves later and a repeated one is the first; `firstWeekday`, `minimumDaysInFirstWeek` | without `PlatformHooks`: non-Gregorian calendars, wrapping arithmetic, week-based math |
| `Date.ISO8601FormatStyle` | full date-and-time formatting and parsing, configurable separators, fractional seconds, `Z`/numeric offsets | field-subset styles (`.year()`, `.month()`, week-of-year) |
| `Date.HTTPFormatStyle` | RFC 9110 HTTP dates (`Sun, 06 Nov 1994 08:49:37 GMT`), formatting and parsing | obsolete RFC 850 and asctime forms |
| `IndexPath` | storage-specialized value type, collection API, `appending`, `dropLast`, `compare`, comparison operators | Objective-C bridging |
| `TimeZone` | fixed GMT offsets (`GMT±HH:MM` identifiers), `gmt`, `secondsFromGMT(for:)`; `current` is the process's zone from `localtime_r`, with its daylight saving | without `PlatformHooks`: named zones, a name for the process's zone |
| `Locale` | identifiers; `current` is fixed to `en_US_POSIX` without `PlatformHooks` | localization data |
| `Data` | bytes, collection API, `append`, `subdata`, capacity, Base64 encode/decode | file I/O, options-based Base64, slices sharing storage |
| `Decimal` | normalized decimal strings, equality | arithmetic |
| `URL` | generic URI parsing: `scheme`, `host`, `port`, `path`, `query`, `fragment`, `lastPathComponent` | resolution against a base, file URLs, normalization |
| `UUID` | random (v4), string round-trip, comparison | — |
| `ComparisonResult` | full | — |
| `Double`/`Float`/`Float16` from `String` | enabled under Embedded Swift (decimal, hex, inf/nan) by exporting the stdlib's `strtod`/`strtof`/`strtof16` stubs | correct rounding only up to a few ulp at extreme decimal exponents; `Float`/`Float16` narrow from `Double` |

All types are `Sendable` and `Hashable`. `Codable` conformances are
intentionally not provided; consumers that need serialization define their own.

Parsing APIs use typed throws (e.g. `throws(ISO8601ParseError)`) because
Embedded Swift cannot represent the `any Error` existential that untyped
`throws` requires. A `try` call site is unaffected and remains compatible with
Foundation's untyped-throwing equivalents.

## Testing

- `swift test` runs the full suite on hosted platforms, including parity
  suites that verify behavior against Foundation where it is available.
- `swift test --enable-all-traits` runs it with `PlatformHooks`, over a
  platform the tests supply: the header defined over Foundation itself.
- `Scripts/embedded-test.sh` cross-compiles the package for bare-metal targets,
  with and without `PlatformHooks`, and runs two smoke tests compiled in
  Embedded Swift mode: one of the package by itself, one linked with a
  platform written in C.
- `Scripts/coverage.sh` enforces line-coverage thresholds.

## The clock and the time zone

`Date()` and `Date.now` call C11's `timespec_get`, which every hosted
platform has, and WASI. `TimeZone.current` is the process's zone, read with
`localtime_r`: its offset follows daylight saving, and `Calendar.current`
counts in it. The C library has no name for that zone, so `identifier` is the
`TZ` variable's value, or `"Local"`.

Both come from a header, `FoundationEmbeddedShims.h`, that asks
`__has_include(<time.h>)`. A bare-metal target with no C library still
builds: there `TimeZone.current` is GMT, and reading the clock stops the
program, since there is none to read. WASI has the clock and no zones, so its
`TimeZone.current` is GMT too.

`Calendar(identifier:)` is in `TimeZone.current`, as Foundation's is. Set
`timeZone` to `.gmt` for arithmetic that mustn't follow the machine.

## Traits

### `PlatformHooks`

Off by default. With it, the package asks a platform for what it cannot know
by itself:

| | Without the trait | With it |
|---|---|---|
| `Date()`, `Date.now` | `timespec_get` | the platform's clock |
| `TimeZone.current` | the process's zone | the user's zone |
| `TimeZone(identifier:)` | `GMT`, `UTC`, `GMT±HHMM` | those, and any name the platform knows |
| `TimeZone` | | `knownTimeZoneIdentifiers`, `isDaylightSavingTime(for:)`, `daylightSavingTimeOffset(for:)`, `nextDaylightSavingTimeTransition(after:)`, `abbreviation(for:)`, `localizedName(for:locale:)` |
| `Locale.current` | `en_US_POSIX` | the user's locale, and `preferredLanguages` |
| `Calendar.current` | Gregorian | the user's calendar |
| `Calendar(identifier:)` | `.gregorian` | Foundation's sixteen |
| `Calendar` arithmetic | the package's own | the platform's, in every calendar |
| `Calendar` | | `dateComponents(_:from:to:)`, `dateInterval(of:for:)`, `ordinality(of:in:for:)`, `nextDate(after:matching:matchingPolicy:direction:)`, `isDateInWeekend`, `isDateInToday` and its neighbours, `compare(_:to:toGranularity:)`, the month, weekday and era symbols |

The platform is joined to the package by the linker. The package calls the
functions declared in
[`FoundationEmbeddedPlatform.h`](Sources/FoundationEmbeddedPlatform/include/FoundationEmbeddedPlatform.h)
and defines none of them; whoever is the platform defines all of them.
Nothing is registered, and an app calls nothing. A build that asks for the
trait and links no platform fails at the link, by name.

A platform in Swift imports the header's module and defines each function
with `@c @implementation`, which checks its type against the header:

```swift
import FoundationEmbeddedPlatform

@c @implementation
public func swift_embedded_clock_now() -> Double {
    board.realTimeClock.secondsSince1970
}
```

A platform in C includes the header and defines them as it would any
function; `EmbeddedTests/Platform/platform.c` is one that knows a clock and
one zone, and answers "no result" for the rest.

With the trait, every public `Calendar` operation is the platform's, the
Gregorian calendar in GMT included. The package's own formats — ISO 8601,
HTTP dates, `Date.description` — keep to the package's own arithmetic, and
never ask the platform.

A trait belongs to the whole build: once one package in a build asks for
it, every module there sees the package with hooks.

```swift
.package(
    url: "https://github.com/PureSwift/swift-embedded-foundation.git",
    from: "0.3.0",
    traits: ["PlatformHooks"]
)
```

### `FloatingPointParsingShims` (enabled by default)

Exports the standard library's floating-point parsing runtime stubs
(`_swift_stdlib_strtod_clocale` and its `strtof`/`strtof16` siblings, plus the
availability helper `_stdlib_isOSVersionAtLeast`) so that `Double`, `Float` and
`Float16` can be created from a `String` under Embedded Swift.

Through **Swift 6.3** these symbols are unresolved in Embedded Swift, so any
use of a float-from-string initializer fails at link time — the trait is
required. This applies to the non-inlinable `Double(Substring)` overload too.

From **Swift 6.4** the standard library parses floating-point strings natively
in Embedded Swift ([swiftlang/swift#85797](https://github.com/swiftlang/swift/pull/85797))
and no longer references these symbols, so the trait is unnecessary. Disable it
on such toolchains, or if you supply the stubs yourself:

```swift
.package(
    url: "https://github.com/PureSwift/swift-embedded-foundation.git",
    from: "1.0.0",
    traits: []
)
```

Disabling the trait removes only the exported symbols; the parser itself
remains compiled and tested on every platform.

## License

MIT

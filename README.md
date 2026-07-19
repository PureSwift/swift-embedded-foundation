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
- **No clock, no I/O, no locale database.** API that requires a system clock
  (`Date()`, `.now`), file system, or ICU data is deliberately omitted.
  Consumers construct values from externally-sourced data.

## Coverage

| Type | Supported | Not supported |
|---|---|---|
| `Date` | intervals since reference/1970 epochs, arithmetic, comparison, `distantPast`/`distantFuture`, `Strideable`, UTC `description` | current time (`now`, `init()`) |
| `DateInterval` | intervals, `contains`, `intersects`, `intersection`, comparison | clock-based `init()` |
| `DateComponents` | era, year, month, day, hour, minute, second, nanosecond, weekday, timeZone | week-based and quarter fields |
| `Calendar` | Gregorian: components ↔ dates, `startOfDay`, `isDate(inSameDayAs:)`, `date(byAdding:)` with day clamping, `range(of:in:)` | non-Gregorian calendars, wrapping arithmetic, week-based math |
| `TimeZone` | fixed GMT offsets (`GMT±HH:MM` identifiers), `gmt`, `secondsFromGMT(for:)` | named zones, DST database |
| `Locale` | identifiers; `current` is fixed to `en_US_POSIX` | localization data |
| `Data` | bytes, collection API, `append`, `subdata`, capacity, Base64 encode/decode | file I/O, options-based Base64, slices sharing storage |
| `Decimal` | normalized decimal strings, equality | arithmetic |
| `URL` | generic URI parsing: `scheme`, `host`, `port`, `path`, `query`, `fragment`, `lastPathComponent` | resolution against a base, file URLs, normalization |
| `UUID` | random (v4), string round-trip, comparison | — |
| `ComparisonResult` | full | — |
| `Double`/`Float`/`Float16` from `String` | enabled under Embedded Swift (decimal, hex, inf/nan) by exporting the stdlib's `strtod`/`strtof`/`strtof16` stubs | correct rounding only up to a few ulp at extreme decimal exponents; `Float`/`Float16` narrow from `Double` |

All types are `Sendable` and `Hashable`. `Codable` conformances are
intentionally not provided; consumers that need serialization define their own.

## Testing

- `swift test` runs the full suite on hosted platforms, including parity
  suites that verify behavior against Foundation where it is available.
- `Scripts/embedded-test.sh` cross-compiles the package for bare-metal targets
  and runs a smoke test compiled in Embedded Swift mode.
- `Scripts/coverage.sh` enforces line-coverage thresholds.

## License

MIT

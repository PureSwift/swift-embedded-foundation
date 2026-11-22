//
//  FoundationEmbeddedPlatform.h
//  FoundationEmbedded
//
//  What a platform defines when `FoundationEmbedded` is built with the
//  `PlatformHooks` trait: the clock, the user's time zone and locale,
//  named time zones, and calendar arithmetic. The package declares these
//  functions and calls them; the platform defines every one of them, and
//  the linker joins the two.
//
//  Conventions:
//
//  - Text in is UTF-8 with a length. Nothing is terminated.
//  - Text out is written to the caller's buffer. The function returns the
//    length the text needs, which may be more than the buffer holds; the
//    caller then asks again with a buffer that size. Less than zero is no
//    text. A list is its items with a line feed between.
//  - A date is seconds since 1970 UTC. `nan` is no date.
//  - Sunday is weekday 1, in every calendar.
//  - A unit, a kind, a style or a policy the platform doesn't know answers
//    as no result. A platform doesn't trap.
//
//  A platform in Swift imports this module and defines each function with
//  `@c @implementation`, which checks its type against this header.
//

#ifndef FOUNDATION_EMBEDDED_PLATFORM_H
#define FOUNDATION_EMBEDDED_PLATFORM_H

#include <stdbool.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

// MARK: - The clock

double   swift_embedded_clock_now(void);

// MARK: - Time zones

/// The user's zone: its identifier.
intptr_t swift_embedded_timezone_current(uint8_t *buffer, intptr_t capacity);

bool     swift_embedded_timezone_is_known(const uint8_t *identifier, intptr_t length);

/// Every identifier the platform knows.
intptr_t swift_embedded_timezone_identifiers(uint8_t *buffer, intptr_t capacity);

/// Seconds east of UTC at a moment.
int32_t  swift_embedded_timezone_offset(const uint8_t *identifier, intptr_t length, double seconds);

/// What daylight saving adds at a moment; 0 outside it.
int32_t  swift_embedded_timezone_daylight_saving_offset(const uint8_t *identifier, intptr_t length, double seconds);

/// The next change of offset after a moment.
double   swift_embedded_timezone_next_transition(const uint8_t *identifier, intptr_t length, double seconds);

intptr_t swift_embedded_timezone_abbreviation(const uint8_t *identifier, intptr_t length, double seconds,
                                              uint8_t *buffer, intptr_t capacity);

/// `style` is Foundation's `NSTimeZone.NameStyle`. A locale of no
/// length is the user's.
intptr_t swift_embedded_timezone_name(const uint8_t *identifier, intptr_t length, int32_t style,
                                      const uint8_t *locale, intptr_t locale_length,
                                      uint8_t *buffer, intptr_t capacity);

// MARK: - The locale

/// The user's locale: its identifier.
intptr_t swift_embedded_locale_current(uint8_t *buffer, intptr_t capacity);

/// The user's languages, in order.
intptr_t swift_embedded_locale_preferred_languages(uint8_t *buffer, intptr_t capacity);

// MARK: - Calendars

/// A calendar as the package's `Calendar` holds it.
typedef struct {
    const uint8_t *identifier;      // "gregorian", "iso8601", "buddhist"
    intptr_t identifier_length;
    const uint8_t *time_zone;
    intptr_t time_zone_length;
    const uint8_t *locale;          // of no length: the user's
    intptr_t locale_length;
    int32_t first_weekday;          // 1 is Sunday; 0: the locale's
    int32_t minimum_days;           // 0: the locale's
} swift_embedded_calendar;

/// A date's fields, in this order: era, year, month, day, hour, minute,
/// second, nanosecond, weekday, weekday ordinal, week of month, week of
/// year, year for week of year, day of year, leap month.
#define SWIFT_EMBEDDED_FIELD_COUNT 15

/// A field that isn't given.
#define SWIFT_EMBEDDED_FIELD_NONE INTPTR_MIN

/// The user's calendar: its identifier.
intptr_t swift_embedded_calendar_current(uint8_t *buffer, intptr_t capacity);

/// What a calendar's first weekday and minimum days are, when the
/// struct leaves them to the locale.
int32_t  swift_embedded_calendar_first_weekday(const swift_embedded_calendar *calendar);
int32_t  swift_embedded_calendar_minimum_days(const swift_embedded_calendar *calendar);

/// Every field of a moment. False if the platform has no such calendar
/// or zone.
bool     swift_embedded_calendar_fields(const swift_embedded_calendar *calendar, double seconds,
                                        intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]);

double   swift_embedded_calendar_date(const swift_embedded_calendar *calendar,
                                      const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]);

double   swift_embedded_calendar_adding(const swift_embedded_calendar *calendar,
                                        const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT],
                                        double seconds, bool wrapping);

/// `units` has a bit for each field wanted, by its place in the list.
bool     swift_embedded_calendar_difference(const swift_embedded_calendar *calendar, int32_t units,
                                            double start, double end,
                                            intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]);

/// Where the unit that holds a moment starts and ends. A unit is a
/// field's place in the list.
double   swift_embedded_calendar_start(const swift_embedded_calendar *calendar, int32_t unit, double seconds);
double   swift_embedded_calendar_end(const swift_embedded_calendar *calendar, int32_t unit, double seconds);

bool     swift_embedded_calendar_range(const swift_embedded_calendar *calendar, int32_t smaller, int32_t larger,
                                       double seconds, intptr_t *lower, intptr_t *count);

/// 0 if there's no answer.
int32_t  swift_embedded_calendar_ordinality(const swift_embedded_calendar *calendar, int32_t smaller,
                                            int32_t larger, double seconds);

/// `policy` is Foundation's `Calendar.MatchingPolicy`, in its order.
double   swift_embedded_calendar_next_date(const swift_embedded_calendar *calendar, double seconds,
                                           const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT],
                                           int32_t policy, bool backward);

bool     swift_embedded_calendar_is_weekend(const swift_embedded_calendar *calendar, double seconds);

/// Names: 0 to 5 are the months (long, short, very short, and each
/// standalone), 6 to 11 the weekdays from Sunday in the same six forms,
/// 12 the eras, 13 the long eras, 14 AM and PM.
intptr_t swift_embedded_calendar_symbols(const swift_embedded_calendar *calendar, int32_t kind,
                                         uint8_t *buffer, intptr_t capacity);

#ifdef __cplusplus
}
#endif

#endif

//
//  Platform/platform.c
//  FoundationEmbedded — Embedded Swift smoke test
//
//  The smallest platform there can be: a clock that says one moment, and one
//  zone, an hour ahead of GMT. It answers "no result" for everything a board
//  with a clock and nothing else wouldn't know, which is how a platform
//  that knows little is written. `Scripts/embedded-test.sh` links it with
//  the package built with the `PlatformHooks` trait.
//

#include "FoundationEmbeddedPlatform.h"

static intptr_t write_text(const char *text, uint8_t *buffer, intptr_t capacity) {
    intptr_t length = 0;
    while (text[length] != 0) {
        length += 1;
    }
    if (buffer != 0 && length <= capacity) {
        for (intptr_t index = 0; index < length; index += 1) {
            buffer[index] = (uint8_t)text[index];
        }
    }
    return length;
}

static const double no_date = 0.0 / 0.0;

// 2026-03-28T12:30:05Z.
double swift_embedded_clock_now(void) { return 1774701005.0; }

intptr_t swift_embedded_timezone_current(uint8_t *buffer, intptr_t capacity) {
    return write_text("Board/Local", buffer, capacity);
}

bool swift_embedded_timezone_is_known(const uint8_t *identifier, intptr_t length) {
    const char *name = "Board/Local";
    for (intptr_t index = 0; index < length; index += 1) {
        if (name[index] == 0 || name[index] != (char)identifier[index]) {
            return false;
        }
    }
    return name[length] == 0;
}

intptr_t swift_embedded_timezone_identifiers(uint8_t *buffer, intptr_t capacity) {
    return write_text("Board/Local", buffer, capacity);
}

int32_t swift_embedded_timezone_offset(const uint8_t *identifier, intptr_t length, double seconds) {
    return swift_embedded_timezone_is_known(identifier, length) ? 3600 : 0;
}

int32_t swift_embedded_timezone_daylight_saving_offset(const uint8_t *identifier, intptr_t length, double seconds) {
    return 0;
}

double swift_embedded_timezone_next_transition(const uint8_t *identifier, intptr_t length, double seconds) {
    return no_date;
}

intptr_t swift_embedded_timezone_abbreviation(const uint8_t *identifier, intptr_t length, double seconds,
                                              uint8_t *buffer, intptr_t capacity) {
    return -1;
}

intptr_t swift_embedded_timezone_name(const uint8_t *identifier, intptr_t length, int32_t style,
                                      const uint8_t *locale, intptr_t locale_length,
                                      uint8_t *buffer, intptr_t capacity) {
    return -1;
}

intptr_t swift_embedded_locale_current(uint8_t *buffer, intptr_t capacity) {
    return write_text("en_GB", buffer, capacity);
}

intptr_t swift_embedded_locale_preferred_languages(uint8_t *buffer, intptr_t capacity) {
    return write_text("en-GB\nde-DE", buffer, capacity);
}

intptr_t swift_embedded_calendar_current(uint8_t *buffer, intptr_t capacity) {
    return write_text("gregorian", buffer, capacity);
}

int32_t swift_embedded_calendar_first_weekday(const swift_embedded_calendar *calendar) { return 2; }

int32_t swift_embedded_calendar_minimum_days(const swift_embedded_calendar *calendar) { return 4; }

bool swift_embedded_calendar_fields(const swift_embedded_calendar *calendar, double seconds,
                                    intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]) {
    return false;
}

double swift_embedded_calendar_date(const swift_embedded_calendar *calendar,
                                    const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]) {
    return no_date;
}

double swift_embedded_calendar_adding(const swift_embedded_calendar *calendar,
                                      const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT],
                                      double seconds, bool wrapping) {
    return no_date;
}

bool swift_embedded_calendar_difference(const swift_embedded_calendar *calendar, int32_t units,
                                        double start, double end,
                                        intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT]) {
    return false;
}

double swift_embedded_calendar_start(const swift_embedded_calendar *calendar, int32_t unit, double seconds) {
    return no_date;
}

double swift_embedded_calendar_end(const swift_embedded_calendar *calendar, int32_t unit, double seconds) {
    return no_date;
}

bool swift_embedded_calendar_range(const swift_embedded_calendar *calendar, int32_t smaller, int32_t larger,
                                   double seconds, intptr_t *lower, intptr_t *count) {
    return false;
}

int32_t swift_embedded_calendar_ordinality(const swift_embedded_calendar *calendar, int32_t smaller,
                                           int32_t larger, double seconds) {
    return 0;
}

double swift_embedded_calendar_next_date(const swift_embedded_calendar *calendar, double seconds,
                                         const intptr_t fields[SWIFT_EMBEDDED_FIELD_COUNT],
                                         int32_t policy, bool backward) {
    return no_date;
}

bool swift_embedded_calendar_is_weekend(const swift_embedded_calendar *calendar, double seconds) {
    return false;
}

intptr_t swift_embedded_calendar_symbols(const swift_embedded_calendar *calendar, int32_t kind,
                                         uint8_t *buffer, intptr_t capacity) {
    return -1;
}

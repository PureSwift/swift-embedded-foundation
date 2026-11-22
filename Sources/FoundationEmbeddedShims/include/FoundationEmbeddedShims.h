//
//  FoundationEmbeddedShims.h
//  FoundationEmbedded
//
//  What the package uses of the C library, where there is one: the clock
//  and the process's time zone. Everything is `static inline`, so nothing
//  is referenced until Swift calls it, and a target with no C library
//  still builds: there the functions answer false.
//
//  Define `FOUNDATION_EMBEDDED_NO_LIBC` to answer false everywhere.
//

#ifndef FOUNDATION_EMBEDDED_SHIMS_H
#define FOUNDATION_EMBEDDED_SHIMS_H

#include <stdbool.h>
#include <stdint.h>

#if !defined(FOUNDATION_EMBEDDED_NO_LIBC) && defined(__has_include)
#if __has_include(<time.h>)
#include <time.h>
#define FOUNDATION_EMBEDDED_HAS_TIME 1
#endif
#if __has_include(<stdlib.h>)
#include <stdlib.h>
#define FOUNDATION_EMBEDDED_HAS_STDLIB 1
#endif
#endif

/// The time by the C library's clock, in seconds since 1970 UTC: C11's
/// `timespec_get`. False where there is no such clock.
static inline bool swift_embedded_shims_now(double *seconds) {
#if defined(FOUNDATION_EMBEDDED_HAS_TIME) && defined(TIME_UTC)
    struct timespec time;
    if (timespec_get(&time, TIME_UTC) != TIME_UTC) {
        return false;
    }
    *seconds = (double)time.tv_sec + (double)time.tv_nsec / 1000000000.0;
    return true;
#else
    (void)seconds;
    return false;
#endif
}

/// The process's time zone at a moment: seconds east of UTC, from
/// `localtime_r` and `tm_gmtoff`. False where the C library has neither,
/// which leaves the zone as GMT.
static inline bool swift_embedded_shims_local_offset(double seconds, int32_t *offset) {
#if defined(FOUNDATION_EMBEDDED_HAS_TIME) \
    && (defined(__APPLE__) || defined(__linux__) || defined(__wasi__) || defined(__FreeBSD__) \
        || defined(__OpenBSD__) || defined(__NetBSD__) || defined(__ANDROID__))
    // Floor, for moments before 1970.
    time_t whole = (time_t)seconds;
    if ((double)whole > seconds) {
        whole -= 1;
    }
    struct tm local;
    if (localtime_r(&whole, &local) == 0) {
        return false;
    }
    *offset = (int32_t)local.tm_gmtoff;
    return true;
#else
    (void)seconds;
    (void)offset;
    return false;
#endif
}

/// The `TZ` environment variable, which is the nearest thing the C
/// library has to the zone's name. Null where it isn't set.
static inline const char *swift_embedded_shims_timezone_name(void) {
#if defined(FOUNDATION_EMBEDDED_HAS_STDLIB) && !defined(_WIN32)
    return getenv("TZ");
#else
    return 0;
#endif
}

#endif

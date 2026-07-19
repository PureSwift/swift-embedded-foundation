//
//  ISO8601.swift
//  FoundationEmbedded
//
//  ISO 8601 date formatting and parsing:
//
//      2024-06-15T14:25:45Z
//
//  ISO 8601 is locale-independent by definition, so this is a byte-level scan
//  over ASCII feeding the Gregorian `Calendar` — no locale data, no ICU.
//
//  Supports the complete date-and-time form with configurable separators,
//  optional fractional seconds, and a numeric or `Z` time-zone designator.
//  Field-subset styles (date-only, week-of-year, and the `.year()`/`.month()`
//  builder family) are not implemented; a formatted string always carries the
//  full date and time.
//

extension Date {

    /// Options for generating and parsing ISO 8601 string representations of
    /// dates.
    public struct ISO8601FormatStyle: Sendable, Hashable {

        /// Separator between date components, e.g. the `-` in `2024-06-15`.
        public enum DateSeparator: String, Sendable, Hashable {
            case dash = "-"
            case omitted = ""
        }

        /// Separator between time components, e.g. the `:` in `14:25:45`.
        public enum TimeSeparator: String, Sendable, Hashable {
            case colon = ":"
            case omitted = ""
        }

        /// Separator within a numeric time-zone offset, e.g. the `:` in `+01:00`.
        public enum TimeZoneSeparator: String, Sendable, Hashable {
            case colon = ":"
            case omitted = ""
        }

        /// Separator between the date and the time.
        public enum DateTimeSeparator: String, Sendable, Hashable {
            case space = " "
            case standard = "'T'"
        }

        public var dateSeparator: DateSeparator
        public var dateTimeSeparator: DateTimeSeparator
        public var timeSeparator: TimeSeparator
        public var timeZoneSeparator: TimeZoneSeparator
        public var includingFractionalSeconds: Bool
        public var timeZone: TimeZone

        public init(
            dateSeparator: DateSeparator = .dash,
            dateTimeSeparator: DateTimeSeparator = .standard,
            timeSeparator: TimeSeparator = .colon,
            timeZoneSeparator: TimeZoneSeparator = .omitted,
            includingFractionalSeconds: Bool = false,
            timeZone: TimeZone = .gmt
        ) {
            self.dateSeparator = dateSeparator
            self.dateTimeSeparator = dateTimeSeparator
            self.timeSeparator = timeSeparator
            self.timeZoneSeparator = timeZoneSeparator
            self.includingFractionalSeconds = includingFractionalSeconds
            self.timeZone = timeZone
        }
    }
}

// MARK: - Builders

extension Date.ISO8601FormatStyle {

    public func dateSeparator(_ separator: DateSeparator) -> Self {
        var copy = self
        copy.dateSeparator = separator
        return copy
    }

    public func dateTimeSeparator(_ separator: DateTimeSeparator) -> Self {
        var copy = self
        copy.dateTimeSeparator = separator
        return copy
    }

    public func timeSeparator(_ separator: TimeSeparator) -> Self {
        var copy = self
        copy.timeSeparator = separator
        return copy
    }

    public func timeZoneSeparator(_ separator: TimeZoneSeparator) -> Self {
        var copy = self
        copy.timeZoneSeparator = separator
        return copy
    }
}

// MARK: - Formatting

extension Date.ISO8601FormatStyle {

    /// The literal text written between the date and the time.
    private var dateTimeSeparatorText: String {
        switch dateTimeSeparator {
        case .space: return " "
        case .standard: return "T"
        }
    }

    /// Formats a date, e.g. `2024-06-15T14:25:45Z`.
    public func format(_ value: Date) -> String {
        var interval = value.timeIntervalSinceReferenceDate
        var milliseconds = 0
        if includingFractionalSeconds {
            let whole = interval.rounded(.down)
            milliseconds = Int(((interval - whole) * 1000).rounded())
            // Rounding up to a full second carries into the seconds field.
            if milliseconds >= 1000 {
                milliseconds = 0
                interval = whole + 1
            } else {
                interval = whole
            }
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let components = calendar.dateComponents(
            fromTimeIntervalSinceReferenceDate: interval)

        var result = ISO8601.pad(components.year ?? 0, 4)
        result += dateSeparator.rawValue
        result += ISO8601.pad(components.month ?? 1, 2)
        result += dateSeparator.rawValue
        result += ISO8601.pad(components.day ?? 1, 2)
        result += dateTimeSeparatorText
        result += ISO8601.pad(components.hour ?? 0, 2)
        result += timeSeparator.rawValue
        result += ISO8601.pad(components.minute ?? 0, 2)
        result += timeSeparator.rawValue
        result += ISO8601.pad(components.second ?? 0, 2)
        if includingFractionalSeconds {
            result += "." + ISO8601.pad(milliseconds, 3)
        }
        result += formattedTimeZone()
        return result
    }

    /// `Z` for GMT, otherwise a numeric offset such as `+0100` or `+01:00`.
    private func formattedTimeZone() -> String {
        let offset = timeZone.secondsFromGMT
        if offset == 0 {
            return "Z"
        }
        let sign = offset < 0 ? "-" : "+"
        let magnitude = offset < 0 ? -offset : offset
        return sign + ISO8601.pad(magnitude / 3600, 2)
            + timeZoneSeparator.rawValue
            + ISO8601.pad((magnitude % 3600) / 60, 2)
    }
}

// MARK: - Parsing

/// Thrown when a string cannot be parsed as an ISO 8601 date.
public struct ISO8601ParseError: Error, Sendable, Hashable {

    /// The string that failed to parse.
    public let value: String
}

extension Date.ISO8601FormatStyle {

    /// Parses an ISO 8601 date. The entire string must be consumed.
    ///
    /// Separators must match this style's configuration. Fractional seconds
    /// are accepted whether or not `includingFractionalSeconds` is set, and a
    /// numeric offset may use either `+01:00` or `+0100` regardless of
    /// `timeZoneSeparator`. A time-zone designator is required.
    ///
    /// - Throws: `ISO8601ParseError` if the string is not a well-formed
    ///   ISO 8601 date.
    ///
    /// - Note: Uses typed throws because Embedded Swift cannot represent the
    ///   `any Error` existential that untyped `throws` requires.
    public func parse(_ value: String) throws(ISO8601ParseError) -> Date {
        let bytes = Array(value.utf8)
        var index = 0

        func fail() -> ISO8601ParseError {
            ISO8601ParseError(value: value)
        }

        func expect(_ character: UInt8) throws(ISO8601ParseError) {
            guard index < bytes.count, bytes[index] == character else {
                throw fail()
            }
            index += 1
        }

        func expect(_ text: String) throws(ISO8601ParseError) {
            for character in text.utf8 {
                try expect(character)
            }
        }

        func digits(_ count: Int) throws(ISO8601ParseError) -> Int {
            guard index + count <= bytes.count else {
                throw fail()
            }
            var result = 0
            for _ in 0..<count {
                let byte = bytes[index]
                guard byte >= UInt8(ascii: "0"), byte <= UInt8(ascii: "9") else {
                    throw fail()
                }
                result = result * 10 + Int(byte - UInt8(ascii: "0"))
                index += 1
            }
            return result
        }

        let year = try digits(4)
        try expect(dateSeparator.rawValue)
        let month = try digits(2)
        try expect(dateSeparator.rawValue)
        let day = try digits(2)
        try expect(dateTimeSeparatorText)
        let hour = try digits(2)
        try expect(timeSeparator.rawValue)
        let minute = try digits(2)
        try expect(timeSeparator.rawValue)
        let second = try digits(2)

        // Optional fractional seconds, accepted regardless of configuration.
        var fraction = 0.0
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            var scale = 0.1
            var sawDigit = false
            while index < bytes.count,
                bytes[index] >= UInt8(ascii: "0"), bytes[index] <= UInt8(ascii: "9") {
                fraction += Double(bytes[index] - UInt8(ascii: "0")) * scale
                scale /= 10
                sawDigit = true
                index += 1
            }
            guard sawDigit else {
                throw fail()
            }
        }

        // Time-zone designator: Z, or a numeric offset with optional separator.
        guard index < bytes.count else {
            throw fail()
        }
        let offset: Int
        if bytes[index] | 0x20 == UInt8(ascii: "z") {
            index += 1
            offset = 0
        } else {
            let sign: Int
            switch bytes[index] {
            case UInt8(ascii: "+"): sign = 1
            case UInt8(ascii: "-"): sign = -1
            default: throw fail()
            }
            index += 1
            let hours = try digits(2)
            if index < bytes.count, bytes[index] == UInt8(ascii: ":") {
                index += 1
            }
            let minutes = try digits(2)
            guard minutes < 60 else {
                throw fail()
            }
            offset = sign * (hours * 3600 + minutes * 60)
        }

        guard index == bytes.count else {
            throw fail()
        }
        guard hour <= 23, minute <= 59, second <= 60 else {
            throw fail()
        }

        var components = DateComponents(
            year: year, month: month, day: day,
            hour: hour, minute: minute,
            // Leap seconds are not representable; 60 is clamped to 59.
            second: second == 60 ? 59 : second)
        components.timeZone = TimeZone(secondsFromGMT: offset)

        guard let date = Calendar(identifier: .gregorian).date(from: components) else {
            throw fail()
        }
        return date + fraction
    }
}

// MARK: - Helpers

enum ISO8601 {

    /// Zero-pads a non-negative integer to at least `width` digits.
    static func pad(_ value: Int, _ width: Int) -> String {
        var string = "\(value)"
        while string.utf8.count < width {
            string = "0" + string
        }
        return string
    }
}

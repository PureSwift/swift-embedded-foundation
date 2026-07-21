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

    /// The byte written between the date and the time.
    var dateTimeSeparatorByte: UInt8 {
        switch dateTimeSeparator {
        case .space: return UInt8(ascii: " ")
        case .standard: return UInt8(ascii: "T")
        }
    }

    /// The byte between date components, or `nil` when omitted.
    var dateSeparatorByte: UInt8? {
        switch dateSeparator {
        case .dash: return UInt8(ascii: "-")
        case .omitted: return nil
        }
    }

    /// The byte between time components, or `nil` when omitted.
    var timeSeparatorByte: UInt8? {
        switch timeSeparator {
        case .colon: return UInt8(ascii: ":")
        case .omitted: return nil
        }
    }

    /// The byte within a numeric zone offset, or `nil` when omitted.
    var timeZoneSeparatorByte: UInt8? {
        switch timeZoneSeparator {
        case .colon: return UInt8(ascii: ":")
        case .omitted: return nil
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

        // Longest form is "±YYYYYY-MM-DDTHH:MM:SS.mmm+HH:MM"; 40 covers it.
        var utf8: [UInt8] = []
        utf8.reserveCapacity(40)
        let dateSeparatorByte = self.dateSeparatorByte
        let timeSeparatorByte = self.timeSeparatorByte

        ASCII.appendPadded(components.year ?? 0, width: 4, to: &utf8)
        if let dateSeparatorByte { utf8.append(dateSeparatorByte) }
        ASCII.appendPadded(components.month ?? 1, width: 2, to: &utf8)
        if let dateSeparatorByte { utf8.append(dateSeparatorByte) }
        ASCII.appendPadded(components.day ?? 1, width: 2, to: &utf8)
        utf8.append(dateTimeSeparatorByte)
        ASCII.appendPadded(components.hour ?? 0, width: 2, to: &utf8)
        if let timeSeparatorByte { utf8.append(timeSeparatorByte) }
        ASCII.appendPadded(components.minute ?? 0, width: 2, to: &utf8)
        if let timeSeparatorByte { utf8.append(timeSeparatorByte) }
        ASCII.appendPadded(components.second ?? 0, width: 2, to: &utf8)
        if includingFractionalSeconds {
            utf8.append(UInt8(ascii: "."))
            ASCII.appendPadded(milliseconds, width: 3, to: &utf8)
        }
        appendFormattedTimeZone(to: &utf8)
        return String(decoding: utf8, as: UTF8.self)
    }

    /// `Z` for GMT, otherwise a numeric offset such as `+0100` or `+01:00`.
    private func appendFormattedTimeZone(to utf8: inout [UInt8]) {
        let offset = timeZone.secondsFromGMT
        guard offset != 0 else {
            utf8.append(UInt8(ascii: "Z"))
            return
        }
        utf8.append(offset < 0 ? UInt8(ascii: "-") : UInt8(ascii: "+"))
        let magnitude = offset < 0 ? -offset : offset
        ASCII.appendPadded(magnitude / 3600, width: 2, to: &utf8)
        if let timeZoneSeparatorByte { utf8.append(timeZoneSeparatorByte) }
        ASCII.appendPadded((magnitude % 3600) / 60, width: 2, to: &utf8)
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
    /// are accepted whether or not they are present, regardless of
    /// `includingFractionalSeconds`, matching the reference implementation.
    /// A numeric offset may use either `+01:00` or `+0100` regardless of
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

        /// Expects an optional separator; `nil` means the style omits it.
        func expect(_ character: UInt8?) throws(ISO8601ParseError) {
            guard let character else { return }
            try expect(character)
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
        try expect(dateSeparatorByte)
        let month = try digits(2)
        try expect(dateSeparatorByte)
        let day = try digits(2)
        try expect(dateTimeSeparatorByte)
        let hour = try digits(2)
        try expect(timeSeparatorByte)
        let minute = try digits(2)
        try expect(timeSeparatorByte)
        let second = try digits(2)

        // Fractional seconds are accepted whether or not the style includes
        // them, and their absence is likewise accepted regardless of the
        // style: the reference implementation is lenient in both directions,
        // parsing `…45.250Z` with a plain style and `…45Z` with a fractional
        // style.
        var fraction = 0.0
        if index < bytes.count, bytes[index] == UInt8(ascii: ".") {
            index += 1
            var scale = 0.1
            var sawDigit = false
            // Any number of digits is accepted, matching the reference.
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


//
//  HTTPDate.swift
//  FoundationEmbedded
//
//  HTTP date formatting and parsing, per RFC 9110 § 5.6.7:
//
//      <day-name>, <day> <month> <year> <hour>:<minute>:<second> GMT
//      Sun, 06 Nov 1994 08:49:37 GMT
//
//  The format is fixed by the specification — English abbreviations, GMT only —
//  so no locale data is involved and the whole thing is a byte-level scan over
//  ASCII feeding the Gregorian `Calendar`.
//
//  Matching Foundation, the leading day-name is accepted but optional, the day
//  of week is not cross-checked against the date, and a leap second (`60`) is
//  clamped to `59`. The obsolete RFC 850 and asctime forms are not accepted.
//

extension Date {

    /// Options for generating and parsing string representations of dates
    /// following the HTTP date format from RFC 9110 § 5.6.7.
    public struct HTTPFormatStyle: Sendable, Hashable {

        public init() {}

        /// Formats a date as `Sun, 06 Nov 1994 08:49:37 GMT`.
        public func format(_ date: Date) -> String {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents(
                [.weekday, .day, .month, .year, .hour, .minute, .second], from: date)

            // "Sun, 06 Nov 1994 08:49:37 GMT" is 29 bytes.
            var utf8: [UInt8] = []
            utf8.reserveCapacity(29)
            if let weekday = components.weekday, let name = HTTPDate.weekdayName(weekday) {
                utf8.append(name.0)
                utf8.append(name.1)
                utf8.append(name.2)
                utf8.append(UInt8(ascii: ","))
                utf8.append(UInt8(ascii: " "))
            }
            ASCII.appendPadded(components.day ?? 1, width: 2, to: &utf8)
            utf8.append(UInt8(ascii: " "))
            let month = HTTPDate.monthName(components.month ?? 1) ?? HTTPDate.januaryName
            utf8.append(month.0)
            utf8.append(month.1)
            utf8.append(month.2)
            utf8.append(UInt8(ascii: " "))
            ASCII.appendPadded(components.year ?? 0, width: 4, to: &utf8)
            utf8.append(UInt8(ascii: " "))
            ASCII.appendPadded(components.hour ?? 0, width: 2, to: &utf8)
            utf8.append(UInt8(ascii: ":"))
            ASCII.appendPadded(components.minute ?? 0, width: 2, to: &utf8)
            utf8.append(UInt8(ascii: ":"))
            ASCII.appendPadded(components.second ?? 0, width: 2, to: &utf8)
            utf8.append(contentsOf: " GMT".utf8)
            return String(decoding: utf8, as: UTF8.self)
        }

        /// Parses an HTTP date. The entire string must be consumed.
        ///
        /// - Throws: `HTTPDateParseError` if the string is not a well-formed
        ///   HTTP date.
        ///
        /// - Note: Uses typed throws because Embedded Swift cannot represent
        ///   the `any Error` existential that untyped `throws` requires. A
        ///   `try` call site remains source-compatible with Foundation's
        ///   untyped-throwing equivalent.
        public func parse(_ value: String) throws(HTTPDateParseError) -> Date {
            let components = try HTTPDate.components(from: value)
            guard let date = Calendar(identifier: .gregorian).date(from: components) else {
                throw HTTPDateParseError(value: value)
            }
            return date
        }
    }
}

/// Thrown when a string cannot be parsed as an HTTP date.
public struct HTTPDateParseError: Error, Sendable, Hashable {

    /// The string that failed to parse.
    public let value: String
}

// MARK: - Parsing

enum HTTPDate {

    /// Decomposes an HTTP date string into Gregorian components in GMT.
    static func components(from value: String) throws(HTTPDateParseError) -> DateComponents {
        let bytes = Array(value.utf8)
        var index = 0

        func fail() -> HTTPDateParseError {
            HTTPDateParseError(value: value)
        }

        func expect(_ character: UInt8) throws(HTTPDateParseError) {
            guard index < bytes.count, bytes[index] == character else {
                throw fail()
            }
            index += 1
        }

        /// Reads exactly `count` ASCII digits.
        func digits(_ count: Int) throws(HTTPDateParseError) -> Int {
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

        func triple() throws(HTTPDateParseError) -> (UInt8, UInt8, UInt8) {
            guard index + 3 <= bytes.count else {
                throw fail()
            }
            defer { index += 3 }
            return (bytes[index], bytes[index + 1], bytes[index + 2])
        }

        var components = DateComponents()

        guard let first = bytes.first else {
            throw fail()
        }
        // The day-name is optional: a leading digit means the day comes first.
        if !(first >= UInt8(ascii: "0") && first <= UInt8(ascii: "9")) {
            guard let weekday = weekdayNumber(try triple()) else {
                throw fail()
            }
            components.weekday = weekday
            try expect(UInt8(ascii: ","))
            try expect(UInt8(ascii: " "))
        }

        components.day = try digits(2)
        try expect(UInt8(ascii: " "))

        guard let month = monthNumber(try triple()) else {
            throw fail()
        }
        components.month = month
        try expect(UInt8(ascii: " "))

        components.year = try digits(4)
        try expect(UInt8(ascii: " "))

        let hour = try digits(2)
        guard hour <= 23 else { throw fail() }
        components.hour = hour
        try expect(UInt8(ascii: ":"))

        let minute = try digits(2)
        guard minute <= 59 else { throw fail() }
        components.minute = minute
        try expect(UInt8(ascii: ":"))

        let second = try digits(2)
        guard second <= 60 else { throw fail() }
        // Leap seconds are not represented; 60 is clamped to 59.
        components.second = second == 60 ? 59 : second
        try expect(UInt8(ascii: " "))

        try expect(UInt8(ascii: "G"))
        try expect(UInt8(ascii: "M"))
        try expect(UInt8(ascii: "T"))

        // Trailing content is rejected.
        guard index == bytes.count else {
            throw fail()
        }

        components.timeZone = .gmt
        return components
    }

    // MARK: Names

    /// A fixed three-letter RFC 9110 name. Bytes rather than a `String` so
    /// that formatting can append straight into its output buffer, and so the
    /// same values round-trip through `weekdayNumber`/`monthNumber`.
    typealias Name = (UInt8, UInt8, UInt8)

    /// The month name used when a component set carries no month.
    static let januaryName: Name = (UInt8(ascii: "J"), UInt8(ascii: "a"), UInt8(ascii: "n"))

    static func weekdayName(_ weekday: Int) -> Name? {
        switch weekday {
        case 1: return (UInt8(ascii: "S"), UInt8(ascii: "u"), UInt8(ascii: "n"))
        case 2: return (UInt8(ascii: "M"), UInt8(ascii: "o"), UInt8(ascii: "n"))
        case 3: return (UInt8(ascii: "T"), UInt8(ascii: "u"), UInt8(ascii: "e"))
        case 4: return (UInt8(ascii: "W"), UInt8(ascii: "e"), UInt8(ascii: "d"))
        case 5: return (UInt8(ascii: "T"), UInt8(ascii: "h"), UInt8(ascii: "u"))
        case 6: return (UInt8(ascii: "F"), UInt8(ascii: "r"), UInt8(ascii: "i"))
        case 7: return (UInt8(ascii: "S"), UInt8(ascii: "a"), UInt8(ascii: "t"))
        default: return nil
        }
    }

    static func monthName(_ month: Int) -> Name? {
        switch month {
        case 1: return januaryName
        case 2: return (UInt8(ascii: "F"), UInt8(ascii: "e"), UInt8(ascii: "b"))
        case 3: return (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "r"))
        case 4: return (UInt8(ascii: "A"), UInt8(ascii: "p"), UInt8(ascii: "r"))
        case 5: return (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "y"))
        case 6: return (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "n"))
        case 7: return (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "l"))
        case 8: return (UInt8(ascii: "A"), UInt8(ascii: "u"), UInt8(ascii: "g"))
        case 9: return (UInt8(ascii: "S"), UInt8(ascii: "e"), UInt8(ascii: "p"))
        case 10: return (UInt8(ascii: "O"), UInt8(ascii: "c"), UInt8(ascii: "t"))
        case 11: return (UInt8(ascii: "N"), UInt8(ascii: "o"), UInt8(ascii: "v"))
        case 12: return (UInt8(ascii: "D"), UInt8(ascii: "e"), UInt8(ascii: "c"))
        default: return nil
        }
    }

    static func weekdayNumber(_ name: Name) -> Int? {
        switch name {
        case (UInt8(ascii: "S"), UInt8(ascii: "u"), UInt8(ascii: "n")): return 1
        case (UInt8(ascii: "M"), UInt8(ascii: "o"), UInt8(ascii: "n")): return 2
        case (UInt8(ascii: "T"), UInt8(ascii: "u"), UInt8(ascii: "e")): return 3
        case (UInt8(ascii: "W"), UInt8(ascii: "e"), UInt8(ascii: "d")): return 4
        case (UInt8(ascii: "T"), UInt8(ascii: "h"), UInt8(ascii: "u")): return 5
        case (UInt8(ascii: "F"), UInt8(ascii: "r"), UInt8(ascii: "i")): return 6
        case (UInt8(ascii: "S"), UInt8(ascii: "a"), UInt8(ascii: "t")): return 7
        default: return nil
        }
    }

    static func monthNumber(_ name: Name) -> Int? {
        switch name {
        case (UInt8(ascii: "J"), UInt8(ascii: "a"), UInt8(ascii: "n")): return 1
        case (UInt8(ascii: "F"), UInt8(ascii: "e"), UInt8(ascii: "b")): return 2
        case (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "r")): return 3
        case (UInt8(ascii: "A"), UInt8(ascii: "p"), UInt8(ascii: "r")): return 4
        case (UInt8(ascii: "M"), UInt8(ascii: "a"), UInt8(ascii: "y")): return 5
        case (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "n")): return 6
        case (UInt8(ascii: "J"), UInt8(ascii: "u"), UInt8(ascii: "l")): return 7
        case (UInt8(ascii: "A"), UInt8(ascii: "u"), UInt8(ascii: "g")): return 8
        case (UInt8(ascii: "S"), UInt8(ascii: "e"), UInt8(ascii: "p")): return 9
        case (UInt8(ascii: "O"), UInt8(ascii: "c"), UInt8(ascii: "t")): return 10
        case (UInt8(ascii: "N"), UInt8(ascii: "o"), UInt8(ascii: "v")): return 11
        case (UInt8(ascii: "D"), UInt8(ascii: "e"), UInt8(ascii: "c")): return 12
        default: return nil
        }
    }
}

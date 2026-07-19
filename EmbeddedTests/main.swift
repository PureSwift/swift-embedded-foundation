//
//  main.swift
//  FoundationEmbedded — Embedded Swift smoke test
//
//  Exercises every shim under real Embedded Swift and traps (nonzero exit) on
//  any mismatch. This is NOT a SwiftPM target: swift-testing/XCTest cannot run
//  under Embedded Swift (no runtime reflection / dynamic test discovery), so
//  this file is compiled and run directly by `Scripts/embedded-test.sh`, which
//  builds it in `-enable-experimental-feature Embedded` mode.
//
//  Keep every check here mirrored by a normal unit test in
//  Tests/FoundationEmbeddedTests — those run the full suite on the hosted
//  platforms; this proves the same behavior holds when compiled for embedded.
//

func check(_ condition: Bool, _ message: StaticString) {
    precondition(condition, message)
}

// MARK: Date

check(Date(timeIntervalSince1970: 978307200).timeIntervalSinceReferenceDate == 0, "Date epoch")
check((Date(timeIntervalSinceReferenceDate: 100) + 10).timeIntervalSinceReferenceDate == 110, "Date +")
check(Date(timeIntervalSinceReferenceDate: 1) < Date(timeIntervalSinceReferenceDate: 2), "Date <")

// MARK: Data

var data = Data([1, 2])
data.append(3)
data.append(contentsOf: [4, 5])
check(Array(data) == [1, 2, 3, 4, 5], "Data append")
check(Data([1, 2, 3]).description == "3 bytes", "Data description")

// MARK: Decimal

check(Decimal(string: "1.2300")?.description == "1.23", "Decimal normalize")
check(Decimal(string: "-0.00")?.description == "0", "Decimal negative zero")
check(Decimal(string: "1.") == nil, "Decimal invalid")

// MARK: URL

check(URL(string: "https://example.com")?.absoluteString == "https://example.com", "URL valid")
check(URL(string: "") == nil, "URL empty")

// MARK: UUID (exercises the vendored hexadecimal helper)

let uuid = UUID(uuid: (0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15))
check(uuid.uuidString == "00010203-0405-0607-0809-0A0B0C0D0E0F", "UUID string")
check(UUID(uuidString: "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")?.uuidString
    == "E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "UUID round trip")
check(UUID(uuidString: "not-a-uuid") == nil, "UUID invalid")
let random = UUID()
check(random.uuid.6 & 0xF0 == 0x40 && random.uuid.8 & 0xC0 == 0x80, "UUID v4")

// MARK: Hexadecimal helper

check(UInt8(0xAB).toHexadecimal() == "AB", "hex byte")
check(UInt16(0x00FF).toHexadecimal() == "00FF", "hex u16")
check(UInt16(hexadecimal: "00ff") == 255, "hex parse")
check(UInt8(hexadecimal: "ZZ") == nil, "hex reject")

// MARK: Locale / TimeZone

check(Locale.current.identifier == "en_US_POSIX", "Locale current")
check(TimeZone.gmt.secondsFromGMT == 0, "TimeZone gmt")
check(TimeZone(secondsFromGMT: 3600)?.identifier == "GMT+0100", "TimeZone offset id")
check(TimeZone(identifier: "GMT+05:30")?.secondsFromGMT == 19800, "TimeZone parse")

// MARK: ComparisonResult / Date extras

check(Date(timeIntervalSinceReferenceDate: 1).compare(Date(timeIntervalSinceReferenceDate: 2)) == .orderedAscending, "Date compare")
check(Date.distantPast < Date.distantFuture, "distant dates")
check(Date(timeInterval: 50, since: Date(timeIntervalSinceReferenceDate: 100)).timeIntervalSinceReferenceDate == 150, "Date since")
check(Date(timeIntervalSinceReferenceDate: 0).description == "2001-01-01 00:00:00 +0000", "Date description")

// MARK: DateInterval

let interval = DateInterval(start: Date(timeIntervalSinceReferenceDate: 0), duration: 100)
check(interval.contains(Date(timeIntervalSinceReferenceDate: 50)), "DateInterval contains")
let other = DateInterval(start: Date(timeIntervalSinceReferenceDate: 50), duration: 100)
check(interval.intersection(with: other)?.duration == 50, "DateInterval intersection")

// MARK: Base64

check(Data(Array("foobar".utf8)).base64EncodedString() == "Zm9vYmFy", "base64 encode")
check(Data(base64Encoded: "Zm9vYmFy").map(Array.init) == Array("foobar".utf8), "base64 decode")
check(Data(base64Encoded: "!!!") == nil, "base64 reject")
check(Array(Data([1, 2, 3, 4, 5]).subdata(in: 1..<4)) == [2, 3, 4], "subdata")

// MARK: URL components

let parsedURL = URL(string: "https://user@example.com:8080/a/b.txt?k=v#frag")!
check(parsedURL.scheme == "https", "URL scheme")
check(parsedURL.host == "example.com", "URL host")
check(parsedURL.port == 8080, "URL port")
check(parsedURL.path == "/a/b.txt", "URL path")
check(parsedURL.query == "k=v", "URL query")
check(parsedURL.fragment == "frag", "URL fragment")
check(parsedURL.lastPathComponent == "b.txt", "URL lastPathComponent")

// MARK: Double parsing (via the exported _swift_stdlib_strtod_clocale)

check(Double("1.5") == 1.5, "Double parse")
check(Double("-2.5e2") == -250, "Double exponent")
check(Double("0x1.8p1") == 3.0, "Double hex")
check(Double("1e999") == .infinity, "Double overflow")
check(Double("nan")?.isNaN == true, "Double nan")
check(Double("1e") == nil, "Double reject")
check(Double("") == nil, "Double empty")
check(Float("1.5") == 1.5, "Float parse")
check(Float("3.4028235e38") == Float.greatestFiniteMagnitude, "Float max")
check(Float16("1.5") == 1.5, "Float16 parse")
check(Float16("65504") == Float16.greatestFiniteMagnitude, "Float16 max")

// MARK: HTTP dates

let httpStyle = Date.HTTPFormatStyle()
let httpReference = Date(timeIntervalSince1970: 784111777)
check(httpStyle.format(httpReference) == "Sun, 06 Nov 1994 08:49:37 GMT", "HTTP format")
check((try? httpStyle.parse("Sun, 06 Nov 1994 08:49:37 GMT")) == httpReference, "HTTP parse")
check((try? httpStyle.parse("06 Nov 1994 08:49:37 GMT")) == httpReference, "HTTP parse without weekday")
check((try? httpStyle.parse("not a date")) == nil, "HTTP reject")

// MARK: ISO 8601

let isoStyle = Date.ISO8601FormatStyle()
let isoReference = Date(timeIntervalSince1970: 1718461545)
check(isoStyle.format(isoReference) == "2024-06-15T14:25:45Z", "ISO 8601 format")
check((try? isoStyle.parse("2024-06-15T14:25:45Z")) == isoReference, "ISO 8601 parse")
check((try? isoStyle.parse("2024-06-15T14:25:45+01:00")) == isoReference - 3600, "ISO 8601 offset")
check((try? isoStyle.parse("2024-06-15T14:25:45")) == nil, "ISO 8601 reject")
let fractionalStyle = Date.ISO8601FormatStyle(includingFractionalSeconds: true)
check(fractionalStyle.format(isoReference) == "2024-06-15T14:25:45.000Z", "ISO 8601 fractional")

// MARK: IndexPath

var indexPath = IndexPath(indexes: [1, 2])
indexPath += IndexPath(index: 3)
check(Array(indexPath) == [1, 2, 3], "IndexPath appending")
check(indexPath[1] == 2, "IndexPath subscript")
check(Array(indexPath.dropLast()) == [1, 2], "IndexPath dropLast")
check(IndexPath(indexes: [1]).compare(IndexPath(indexes: [1, 2])) == .orderedAscending, "IndexPath compare")
check(IndexPath(indexes: [1, 2]) == IndexPath(arrayLiteral: 1, 2), "IndexPath equality")

// MARK: Calendar

let calendar = Calendar.current
check(calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))?
    .timeIntervalSinceReferenceDate == 0, "Calendar date(from:)")
check(calendar.date(from: DateComponents(year: 2001)) == nil, "Calendar missing fields")
let components = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSinceReferenceDate: -1))
check(components.year == 2000 && components.month == 12 && components.day == 31, "Calendar decompose")
check(calendar.component(.weekday, from: Date(timeIntervalSinceReferenceDate: 0)) == 2, "Calendar weekday")
let jan31 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 31))!
let clamped = calendar.date(byAdding: .month, value: 1, to: jan31)!
check(calendar.component(.day, from: clamped) == 29, "Calendar clamp to leap February")
check(calendar.startOfDay(for: Date(timeIntervalSinceReferenceDate: 3600)) == Date(timeIntervalSinceReferenceDate: 0), "Calendar startOfDay")
check(calendar.range(of: .day, in: .month, for: jan31) == 1..<32, "Calendar range")

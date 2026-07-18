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

// MARK: Calendar

let calendar = Calendar.current
check(calendar.date(from: DateComponents(year: 2001, month: 1, day: 1))?
    .timeIntervalSinceReferenceDate == 0, "Calendar date(from:)")
check(calendar.date(from: DateComponents(year: 2001)) == nil, "Calendar missing fields")
let components = calendar.dateComponents([.year, .month, .day], from: Date(timeIntervalSinceReferenceDate: -1))
check(components.year == 2000 && components.month == 12 && components.day == 31, "Calendar decompose")
check(calendar.component(.weekday, from: Date(timeIntervalSinceReferenceDate: 0)) == 2, "Calendar weekday")

//
//  UUID.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `UUID` for platforms without Foundation
//  (e.g. Embedded Swift). Modeled on PureSwift/Bluetooth's embedded UUID.
//  Not API-complete — storage-layer round-tripping only.
//

public struct UUID: Sendable {

    public typealias ByteValue = (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8)

    public let uuid: ByteValue

    public init(uuid: ByteValue) {
        self.uuid = uuid
    }
}

// MARK: - Random Initialization

extension UUID {

    /// Create a new UUID with RFC 4122 version 4 random bytes.
    public init() {
        var uuidBytes: ByteValue = (
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255),
            .random(in: 0...255)
        )

        // Set the version to 4 (random UUID)
        uuidBytes.6 = (uuidBytes.6 & 0x0F) | 0x40

        // Set the variant to RFC 4122
        uuidBytes.8 = (uuidBytes.8 & 0x3F) | 0x80

        self.init(uuid: uuidBytes)
    }
}

// MARK: - String Parsing / Formatting

extension UUID {

    /// The byte offsets of the four hyphens in a UUID string.
    private static let separatorOffsets = (8, 13, 18, 23)

    /// Create a UUID from a string such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F".
    ///
    /// Returns nil for invalid strings.
    public init?(uuidString string: String) {
        var bytes: ByteValue = (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0)
        let parsed = string.utf8.withContiguousStorageIfAvailable { input -> Bool in
            UUID.parse(input, into: &bytes)
        }
        switch parsed {
        case .some(true):
            self.init(uuid: bytes)
        case .some(false):
            return nil
        case .none:
            // Non-contiguous UTF-8 (a bridged string) needs one copy first.
            let input = Array(string.utf8)
            guard input.withUnsafeBufferPointer({ UUID.parse($0, into: &bytes) }) else {
                return nil
            }
            self.init(uuid: bytes)
        }
    }

    /// Parses the canonical 8-4-4-4-12 hyphenated form into `bytes`.
    ///
    /// Returns `false` — leaving `bytes` in an unspecified state — for any
    /// input that is not exactly 36 bytes with hyphens in the right places and
    /// hex digits everywhere else.
    private static func parse(_ input: UnsafeBufferPointer<UInt8>, into bytes: inout ByteValue) -> Bool {
        guard input.count == 36,
            input[separatorOffsets.0] == UInt8(ascii: "-"),
            input[separatorOffsets.1] == UInt8(ascii: "-"),
            input[separatorOffsets.2] == UInt8(ascii: "-"),
            input[separatorOffsets.3] == UInt8(ascii: "-")
        else {
            return false
        }
        return withUnsafeMutableBytes(of: &bytes) { output in
            var source = 0
            for target in 0..<16 {
                if source == separatorOffsets.0 || source == separatorOffsets.1
                    || source == separatorOffsets.2 || source == separatorOffsets.3 {
                    source += 1
                }
                guard let high = hexNibble(input[source]),
                    let low = hexNibble(input[source + 1])
                else {
                    return false
                }
                output[target] = high << 4 | low
                source += 2
            }
            return true
        }
    }

    /// Returns a string created from the UUID, such as "E621E1F8-C36C-495A-93FC-0C247A3E6E5F"
    public var uuidString: String {
        withUnsafeTemporaryAllocation(of: UInt8.self, capacity: 36) { output in
            Swift.withUnsafeBytes(of: uuid) { input in
                var target = 0
                for source in 0..<16 {
                    if target == UUID.separatorOffsets.0 || target == UUID.separatorOffsets.1
                        || target == UUID.separatorOffsets.2 || target == UUID.separatorOffsets.3 {
                        output[target] = UInt8(ascii: "-")
                        target += 1
                    }
                    let byte = input[source]
                    output[target] = UUID.hexDigit(byte >> 4)
                    output[target + 1] = UUID.hexDigit(byte & 0x0F)
                    target += 2
                }
            }
            return String(decoding: output, as: UTF8.self)
        }
    }

    /// Maps a nibble (0–15) to its uppercase ASCII hex digit.
    private static func hexDigit(_ value: UInt8) -> UInt8 {
        value < 10 ? (UInt8(ascii: "0") + value) : (UInt8(ascii: "A") + value - 10)
    }

    /// Maps an ASCII hex digit to its value, or `nil` if it isn't one.
    private static func hexNibble(_ byte: UInt8) -> UInt8? {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"): return byte - UInt8(ascii: "0")
        case UInt8(ascii: "A")...UInt8(ascii: "F"): return byte - UInt8(ascii: "A") + 10
        case UInt8(ascii: "a")...UInt8(ascii: "f"): return byte - UInt8(ascii: "a") + 10
        default: return nil
        }
    }
}

// MARK: - Equatable

extension UUID: Equatable {

    public static func == (lhs: UUID, rhs: UUID) -> Bool {
        Swift.withUnsafeBytes(of: lhs.uuid) { lhsPtr in
            Swift.withUnsafeBytes(of: rhs.uuid) { rhsPtr in
                let lhsTuple = lhsPtr.loadUnaligned(as: (UInt64, UInt64).self)
                let rhsTuple = rhsPtr.loadUnaligned(as: (UInt64, UInt64).self)
                return (lhsTuple.0 ^ rhsTuple.0) | (lhsTuple.1 ^ rhsTuple.1) == 0
            }
        }
    }
}

// MARK: - Hashable

extension UUID: Hashable {

    public func hash(into hasher: inout Hasher) {
        Swift.withUnsafeBytes(of: uuid) { buffer in
            hasher.combine(bytes: buffer)
        }
    }
}

// MARK: - CustomStringConvertible

extension UUID: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        uuidString
    }

    public var debugDescription: String {
        description
    }
}

// MARK: - Comparable

extension UUID: Comparable {

    public static func < (lhs: UUID, rhs: UUID) -> Bool {
        var leftUUID = lhs.uuid
        var rightUUID = rhs.uuid
        var result: Int = 0
        var diff: Int = 0
        Swift.withUnsafeBytes(of: &leftUUID) { leftPtr in
            Swift.withUnsafeBytes(of: &rightUUID) { rightPtr in
                for offset in (0..<MemoryLayout<ByteValue>.size).reversed() {
                    diff = Int(leftPtr.load(fromByteOffset: offset, as: UInt8.self)) - Int(rightPtr.load(fromByteOffset: offset, as: UInt8.self))
                    result = (result & (((diff - 1) & ~diff) >> 8)) | diff
                }
            }
        }
        return result < 0
    }
}


//
//  Data.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `Data` for platforms without Foundation
//  (e.g. Embedded Swift). Not API-complete — storage-layer round-tripping only.
//

@frozen
public struct Data: Sendable {

    /// - Note: `@usableFromInline` so the collection conformance below can be
    ///   inlined into consumers. Element access on a byte buffer is not worth
    ///   a cross-module call.
    @usableFromInline
    internal var bytes: [UInt8]

    @inlinable
    public init() {
        self.bytes = []
    }

    @inlinable
    public init<S: Sequence>(_ elements: S) where S.Element == UInt8 {
        self.bytes = Array(elements)
    }

    /// Adopts an already-built byte array without copying it.
    @usableFromInline
    init(storage: [UInt8]) {
        self.bytes = storage
    }

    @inlinable
    public init(repeating byte: UInt8, count: Int) {
        self.bytes = Array(repeating: byte, count: count)
    }

    /// Creates an empty data buffer of a specified capacity.
    @inlinable
    public init(capacity: Int) {
        self.bytes = []
        self.bytes.reserveCapacity(capacity)
    }
}

// MARK: - Collection

extension Data: RandomAccessCollection, MutableCollection {

    public typealias Element = UInt8
    public typealias Index = Int

    @inlinable
    public var startIndex: Int { bytes.startIndex }

    @inlinable
    public var endIndex: Int { bytes.endIndex }

    @inlinable
    public subscript(position: Int) -> UInt8 {
        get { bytes[position] }
        set { bytes[position] = newValue }
    }

    @inlinable
    public func index(after i: Int) -> Int { bytes.index(after: i) }

    @inlinable
    public func index(before i: Int) -> Int { bytes.index(before: i) }
}

extension Data {

    @inlinable
    public mutating func append(_ byte: UInt8) {
        bytes.append(byte)
    }

    @inlinable
    public mutating func append<S: Sequence>(contentsOf newElements: S) where S.Element == UInt8 {
        bytes.append(contentsOf: newElements)
    }

    /// Appends the contents of another data buffer.
    @inlinable
    public mutating func append(_ other: Data) {
        bytes.append(contentsOf: other.bytes)
    }

    /// Returns a new copy of the data in the specified range.
    @inlinable
    public func subdata(in range: Range<Int>) -> Data {
        // Use Array slice to avoid the inefficient `Sequence` initializer.
        Data(storage: Array(bytes[range]))
    }

    /// Reserves capacity for at least the given number of bytes.
    @inlinable
    public mutating func reserveCapacity(_ minimumCapacity: Int) {
        bytes.reserveCapacity(minimumCapacity)
    }
}

// MARK: - Equatable, Hashable

extension Data: Equatable, Hashable {

    @inlinable
    public static func == (lhs: Data, rhs: Data) -> Bool {
        lhs.bytes == rhs.bytes
    }

    @inlinable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(bytes)
    }
}

// MARK: - CustomStringConvertible

extension Data: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        "\(count) bytes"
    }

    public var debugDescription: String {
        description
    }
}

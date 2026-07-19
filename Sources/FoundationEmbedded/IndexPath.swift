//
//  IndexPath.swift
//  FoundationEmbedded
//
//  A list of indexes that together represent the path to a specific node in a
//  tree of nested arrays. Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.IndexPath`.
//
//  Storage is specialized for the common short paths so that a one- or
//  two-element path needs no heap allocation, matching the reference
//  implementation's layout.
//

public struct IndexPath: Sendable {

    public typealias Element = Int

    fileprivate enum Storage: Sendable {
        case empty
        case single(Int)
        case pair(Int, Int)
        case array([Int])

        var count: Int {
            switch self {
            case .empty: return 0
            case .single: return 1
            case .pair: return 2
            case .array(let array): return array.count
            }
        }

        subscript(index: Int) -> Int {
            get {
                switch self {
                case .empty:
                    preconditionFailure("Index out of range")
                case .single(let value):
                    precondition(index == 0, "Index out of range")
                    return value
                case .pair(let first, let second):
                    switch index {
                    case 0: return first
                    case 1: return second
                    default: preconditionFailure("Index out of range")
                    }
                case .array(let array):
                    return array[index]
                }
            }
            set {
                switch self {
                case .empty:
                    preconditionFailure("Index out of range")
                case .single:
                    precondition(index == 0, "Index out of range")
                    self = .single(newValue)
                case .pair(let first, let second):
                    switch index {
                    case 0: self = .pair(newValue, second)
                    case 1: self = .pair(first, newValue)
                    default: preconditionFailure("Index out of range")
                    }
                case .array(var array):
                    // Avoid a temporary copy while mutating in place.
                    self = .empty
                    array[index] = newValue
                    self = .array(array)
                }
            }
        }

        /// The indexes as a flat array.
        var allValues: [Int] {
            switch self {
            case .empty: return []
            case .single(let value): return [value]
            case .pair(let first, let second): return [first, second]
            case .array(let array): return array
            }
        }

        /// Builds the most compact representation for the given indexes.
        static func make(_ indexes: [Int]) -> Storage {
            switch indexes.count {
            case 0: return .empty
            case 1: return .single(indexes[0])
            case 2: return .pair(indexes[0], indexes[1])
            default: return .array(indexes)
            }
        }
    }

    fileprivate var storage: Storage

    fileprivate init(storage: Storage) {
        self.storage = storage
    }

    /// Creates an empty index path.
    public init() {
        self.storage = .empty
    }

    /// Creates an index path with a single index.
    public init(index: Element) {
        self.storage = .single(index)
    }

    /// Creates an index path with the given indexes.
    public init(indexes: [Element]) {
        self.storage = Storage.make(indexes)
    }

    /// Creates an index path with the given sequence of indexes.
    public init<ElementSequence: Sequence>(indexes: ElementSequence) where ElementSequence.Element == Element {
        self.storage = Storage.make(Array(indexes))
    }
}

// MARK: - ExpressibleByArrayLiteral

extension IndexPath: ExpressibleByArrayLiteral {

    public init(arrayLiteral indexes: Element...) {
        self.storage = Storage.make(indexes)
    }
}

// MARK: - Collection

extension IndexPath: RandomAccessCollection, MutableCollection {

    public typealias Index = Int
    public typealias Indices = DefaultIndices<IndexPath>

    public var startIndex: Index { 0 }

    public var endIndex: Index { storage.count }

    public var count: Int { storage.count }

    public subscript(index: Index) -> Element {
        get { storage[index] }
        set { storage[index] = newValue }
    }

    public subscript(range: Range<Index>) -> IndexPath {
        get { IndexPath(indexes: Array(storage.allValues[range])) }
        set {
            var values = storage.allValues
            values.replaceSubrange(range, with: newValue.storage.allValues)
            storage = Storage.make(values)
        }
    }

    public func index(before i: Index) -> Index { i - 1 }

    public func index(after i: Index) -> Index { i + 1 }
}

// MARK: - Appending and Removing

extension IndexPath {

    /// Returns a new index path with the given index appended.
    public func appending(_ other: Element) -> IndexPath {
        var values = storage.allValues
        values.append(other)
        return IndexPath(storage: Storage.make(values))
    }

    /// Returns a new index path with the given path appended.
    public func appending(_ other: IndexPath) -> IndexPath {
        appending(other.storage.allValues)
    }

    /// Returns a new index path with the given indexes appended.
    public func appending(_ other: [Element]) -> IndexPath {
        var values = storage.allValues
        values.append(contentsOf: other)
        return IndexPath(storage: Storage.make(values))
    }

    /// Returns a new index path without its last element.
    ///
    /// Returns an empty index path when already empty.
    public func dropLast() -> IndexPath {
        var values = storage.allValues
        if values.isEmpty == false {
            values.removeLast()
        }
        return IndexPath(storage: Storage.make(values))
    }

    public static func + (lhs: IndexPath, rhs: IndexPath) -> IndexPath {
        lhs.appending(rhs)
    }

    public static func += (lhs: inout IndexPath, rhs: IndexPath) {
        lhs = lhs + rhs
    }
}

// MARK: - Equatable, Hashable, Comparable

extension IndexPath: Equatable, Hashable, Comparable {

    public static func == (lhs: IndexPath, rhs: IndexPath) -> Bool {
        lhs.storage.allValues == rhs.storage.allValues
    }

    /// Compares two index paths lexicographically, shorter paths ordering first
    /// when one is a prefix of the other.
    public func compare(_ other: IndexPath) -> ComparisonResult {
        let length = Swift.min(count, other.count)
        for index in 0..<length {
            let value = self[index]
            let otherValue = other[index]
            if value < otherValue {
                return .orderedAscending
            } else if value > otherValue {
                return .orderedDescending
            }
        }
        if count > other.count {
            return .orderedDescending
        } else if count < other.count {
            return .orderedAscending
        }
        return .orderedSame
    }

    public func hash(into hasher: inout Hasher) {
        // Every index participates in ==, so every index must be hashed.
        for index in 0..<count {
            hasher.combine(self[index])
        }
    }

    public static func < (lhs: IndexPath, rhs: IndexPath) -> Bool {
        lhs.compare(rhs) == .orderedAscending
    }

    public static func <= (lhs: IndexPath, rhs: IndexPath) -> Bool {
        lhs.compare(rhs) != .orderedDescending
    }

    public static func > (lhs: IndexPath, rhs: IndexPath) -> Bool {
        lhs.compare(rhs) == .orderedDescending
    }

    public static func >= (lhs: IndexPath, rhs: IndexPath) -> Bool {
        lhs.compare(rhs) != .orderedAscending
    }
}

// MARK: - CustomStringConvertible

extension IndexPath: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        "\(storage.allValues)"
    }

    public var debugDescription: String {
        description
    }
}

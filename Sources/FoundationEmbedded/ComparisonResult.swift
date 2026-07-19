//
//  ComparisonResult.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `ComparisonResult` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.ComparisonResult`.
//

/// Indicates how items are ordered, from the first one given to the last
/// (that is, left to right in code).
@frozen
public enum ComparisonResult: Int, Sendable {
    case orderedAscending = -1
    case orderedSame = 0
    case orderedDescending = 1
}

// MARK: - Equatable, Hashable

extension ComparisonResult: Equatable, Hashable {}

// MARK: - Codable

#if !hasFeature(Embedded)
extension ComparisonResult: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(Int.self)
        guard let value = ComparisonResult(rawValue: rawValue) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Attempted to decode ComparisonResult from invalid value."))
        }
        self = value
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}
#endif

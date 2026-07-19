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

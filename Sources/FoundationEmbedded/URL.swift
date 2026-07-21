//
//  URL.swift
//  FoundationEmbedded
//
//  Minimal Foundation-free `URL` for platforms without Foundation
//  (e.g. Embedded Swift). Compiles on any platform; the consumer is
//  responsible for gating between this and `Foundation.URL`.
//
//  Parses the generic URI syntax (scheme, authority, path, query, fragment)
//  strictly from the stored string — no normalization, resolution against a
//  base, or file-system semantics.
//
//  URLs with an opaque path (a scheme, no authority, and a path not beginning
//  with "/", e.g. `mailto:someone@example.com`) still report the remainder
//  as their path, matching the reference implementation. See `parse(_:)`.
//

public struct URL: Sendable {

    public let absoluteString: String

    public init?(string: String) {
        guard string.isEmpty == false else {
            return nil
        }
        self.absoluteString = string
    }
}

// MARK: - Components

extension URL {

    /// The scheme, e.g. `"https"`, or `nil` if the URL has none.
    public var scheme: String? {
        parsed().scheme
    }

    /// The host, percent-decoded, or `nil` if the URL has no authority.
    public var host: String? {
        parsed().host.map(URL.percentDecode)
    }

    /// The port, or `nil` if the URL specifies none.
    public var port: Int? {
        parsed().port
    }

    /// The path, percent-decoded, without any trailing slash (the root path
    /// `"/"` is preserved).
    ///
    /// For an opaque URL — a scheme with no authority whose path does not
    /// begin with `/`, such as `mailto:someone@example.com` — this is the
    /// entire scheme-specific part (`"someone@example.com"`).
    public var path: String {
        var path = URL.percentDecode(parsed().path)
        if path.utf8.count > 1, path.hasSuffix("/") {
            path.removeLast()
        }
        return path
    }

    /// The query string, without the leading `?`, still percent-encoded.
    public var query: String? {
        parsed().query
    }

    /// The fragment, without the leading `#`, still percent-encoded.
    public var fragment: String? {
        parsed().fragment
    }

    /// The last component of the path, percent-decoded.
    ///
    /// A trailing slash is ignored (`/a/b/` yields `"b"`); the root path
    /// yields `"/"`; an empty path yields `""`.
    public var lastPathComponent: String {
        let path = self.path
        guard path.isEmpty == false else { return "" }
        guard path != "/" else { return "/" }
        var characters = Array(path.utf8)
        if characters.last == UInt8(ascii: "/") {
            characters.removeLast()
        }
        if let separator = characters.lastIndex(of: UInt8(ascii: "/")) {
            characters.removeFirst(separator + 1)
        }
        return String(decoding: characters, as: UTF8.self)
    }

    private struct Parsed {
        var scheme: String?
        var host: String?
        var port: Int?
        var path: String = ""
        var query: String?
        var fragment: String?
        /// Whether the string carried a `//` authority component.
        var hasAuthority = false
    }

    /// Splits the stored string into generic URI components.
    ///
    /// - Note: Every component accessor parses on demand, so this runs once per
    ///   property read. It scans the string's own UTF-8 storage in place rather
    ///   than copying it into an array first, which is what that repetition
    ///   used to cost.
    private func parsed() -> Parsed {
        let utf8 = absoluteString.utf8
        if let result = utf8.withContiguousStorageIfAvailable({ URL.parse($0[...]) }) {
            return result
        }
        // Non-contiguous UTF-8 (a bridged string) needs one copy first.
        return Array(utf8).withUnsafeBufferPointer { URL.parse($0[...]) }
    }

    private static func parse(_ input: Slice<UnsafeBufferPointer<UInt8>>) -> Parsed {
        var result = Parsed()
        var rest = input

        // Fragment: everything after the first "#".
        if let hash = rest.firstIndex(of: UInt8(ascii: "#")) {
            result.fragment = String(decoding: rest[(hash + 1)...], as: UTF8.self)
            rest = rest[..<hash]
        }
        // Query: everything after the first "?" (before the fragment).
        if let question = rest.firstIndex(of: UInt8(ascii: "?")) {
            result.query = String(decoding: rest[(question + 1)...], as: UTF8.self)
            rest = rest[..<question]
        }
        // Scheme: ALPHA *( ALPHA / DIGIT / "+" / "-" / "." ) followed by ":".
        if let colon = rest.firstIndex(of: UInt8(ascii: ":")),
            colon > rest.startIndex,
            URL.isSchemeStart(rest[rest.startIndex]),
            rest[rest.startIndex..<colon].allSatisfy(URL.isSchemeCharacter) {
            result.scheme = String(decoding: rest[rest.startIndex..<colon], as: UTF8.self)
            rest = rest[(colon + 1)...]
        }
        // Authority: present when the remainder starts with "//".
        if rest.count >= 2,
            rest[rest.startIndex] == UInt8(ascii: "/"),
            rest[rest.startIndex + 1] == UInt8(ascii: "/") {
            result.hasAuthority = true
            rest = rest[(rest.startIndex + 2)...]
            var authority = rest
            if let slash = rest.firstIndex(of: UInt8(ascii: "/")) {
                authority = rest[..<slash]
                rest = rest[slash...]
            } else {
                rest = rest[rest.endIndex...]
            }
            // Drop userinfo.
            if let at = authority.lastIndex(of: UInt8(ascii: "@")) {
                authority = authority[(at + 1)...]
            }
            // IPv6 literal: host is the bracketed section, brackets stripped.
            if authority.first == UInt8(ascii: "[") {
                if let close = authority.firstIndex(of: UInt8(ascii: "]")) {
                    result.host = String(decoding: authority[(authority.startIndex + 1)..<close], as: UTF8.self)
                    authority = authority[(close + 1)...]
                }
            } else if let colon = authority.firstIndex(of: UInt8(ascii: ":")) {
                result.host = String(decoding: authority[..<colon], as: UTF8.self)
                authority = authority[colon...]
            } else {
                result.host = String(decoding: authority, as: UTF8.self)
                authority = authority[authority.endIndex...]
            }
            // Port after the remaining ":".
            if authority.first == UInt8(ascii: ":") {
                let digits = authority.dropFirst()
                if digits.isEmpty == false, digits.allSatisfy({ $0 >= UInt8(ascii: "0") && $0 <= UInt8(ascii: "9") }) {
                    result.port = digits.reduce(0) { $0 * 10 + Int($1 - UInt8(ascii: "0")) }
                }
            }
        }
        result.path = String(decoding: rest, as: UTF8.self)
        return result
    }

    private static func isSchemeStart(_ byte: UInt8) -> Bool {
        (byte >= UInt8(ascii: "A") && byte <= UInt8(ascii: "Z"))
            || (byte >= UInt8(ascii: "a") && byte <= UInt8(ascii: "z"))
    }

    private static func isSchemeCharacter(_ byte: UInt8) -> Bool {
        isSchemeStart(byte)
            || (byte >= UInt8(ascii: "0") && byte <= UInt8(ascii: "9"))
            || byte == UInt8(ascii: "+") || byte == UInt8(ascii: "-") || byte == UInt8(ascii: ".")
    }

    /// Decodes `%XX` escapes; malformed escapes are passed through unchanged.
    private static func percentDecode(_ string: String) -> String {
        let utf8 = string.utf8
        // Nothing to decode is the common case, and it can keep the original
        // storage instead of rebuilding the string byte by byte.
        guard utf8.contains(UInt8(ascii: "%")) else {
            return string
        }
        let input = Array(utf8)
        var output: [UInt8] = []
        output.reserveCapacity(input.count)
        var index = 0
        while index < input.count {
            if input[index] == UInt8(ascii: "%"), index + 2 < input.count,
                let high = hexNibble(input[index + 1]),
                let low = hexNibble(input[index + 2]) {
                output.append(high << 4 | low)
                index += 3
            } else {
                output.append(input[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
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

// MARK: - Equatable, Hashable

extension URL: Equatable, Hashable {}

// MARK: - CustomStringConvertible

extension URL: CustomStringConvertible, CustomDebugStringConvertible {

    public var description: String {
        absoluteString
    }

    public var debugDescription: String {
        description
    }
}

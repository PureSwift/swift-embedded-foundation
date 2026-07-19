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
    /// `"/"` is preserved). Empty if the URL has no path.
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
    }

    /// Splits the stored string into generic URI components.
    private func parsed() -> Parsed {
        var result = Parsed()
        var rest = Array(absoluteString.utf8)[...]

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
        let input = Array(string.utf8)
        var output: [UInt8] = []
        output.reserveCapacity(input.count)
        var index = 0
        while index < input.count {
            if input[index] == UInt8(ascii: "%"), index + 2 < input.count,
                let high = UInt8(hexadecimal: String(decoding: input[(index + 1)...(index + 2)], as: UTF8.self)) {
                output.append(high)
                index += 3
            } else {
                output.append(input[index])
                index += 1
            }
        }
        return String(decoding: output, as: UTF8.self)
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

// MARK: - Codable

#if !hasFeature(Embedded)
extension URL: Codable {

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let string = try container.decode(String.self)
        guard let url = URL(string: string) else {
            throw DecodingError.dataCorrupted(
                DecodingError.Context(
                    codingPath: decoder.codingPath,
                    debugDescription: "Attempted to decode URL from invalid string."))
        }
        self = url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(absoluteString)
    }
}
#endif

#if canImport(Foundation)
import Testing
import Foundation
@testable import FoundationEmbedded

/// Confirms `FoundationEmbedded.URL` component parsing matches
/// `Foundation.URL` for well-formed URLs.
@Suite struct URLFoundationParityTests {

    private let urls = [
        "https://example.com",
        "https://example.com/",
        "https://example.com/a/b.txt",
        "https://example.com/a/b/",
        "https://user:pass@example.com:8080/a/b.txt?key=value&x=1#section",
        "http://example.com:80/path",
        "https://example.com/hello%20world/file%2Bname",
        "https://example.com/?q=a%20b",
        "mailto:someone@example.com",
        "ftp://files.example.org/pub/readme",
        "https://example.com/a#frag",
    ]

    @Test func componentsMatchFoundation() {
        for string in urls {
            let ours = FoundationEmbedded.URL(string: string)!
            let theirs = Foundation.URL(string: string)!
            #expect(ours.scheme == theirs.scheme, "scheme mismatch for \(string)")
            #expect(ours.host == theirs.host, "host mismatch for \(string)")
            #expect(ours.port == theirs.port, "port mismatch for \(string)")
            #expect(ours.path == theirs.path, "path mismatch for \(string)")
            #expect(ours.query == theirs.query, "query mismatch for \(string)")
            #expect(ours.fragment == theirs.fragment, "fragment mismatch for \(string)")
        }
    }

    @Test func lastPathComponentMatchesFoundation() {
        for string in urls {
            let ours = FoundationEmbedded.URL(string: string)!
            let theirs = Foundation.URL(string: string)!
            #expect(ours.lastPathComponent == theirs.lastPathComponent,
                "lastPathComponent mismatch for \(string)")
        }
    }
}
#endif

import Testing
@testable import FoundationEmbedded

@Suite struct URLTests {

    @Test func validAndInvalid() {
        #expect(URL(string: "https://example.com")?.absoluteString == "https://example.com")
        #expect(URL(string: "") == nil)
    }

    @Test func equatableAndHashable() {
        #expect(URL(string: "a://b") == URL(string: "a://b"))
        #expect(URL(string: "a://b") != URL(string: "a://c"))
        #expect(URL(string: "a://b")?.hashValue == URL(string: "a://b")?.hashValue)
    }

    @Test func description() {
        let url = URL(string: "x://y")
        #expect(url?.description == "x://y")
        #expect(url?.debugDescription == "x://y")
    }

    // MARK: - Components

    @Test func fullURL() {
        let url = URL(string: "https://user:pass@example.com:8080/a/b.txt?key=value&x=1#section")!
        #expect(url.scheme == "https")
        #expect(url.host == "example.com")
        #expect(url.port == 8080)
        #expect(url.path == "/a/b.txt")
        #expect(url.query == "key=value&x=1")
        #expect(url.fragment == "section")
        #expect(url.lastPathComponent == "b.txt")
    }

    @Test func minimalURL() {
        let url = URL(string: "https://example.com")!
        #expect(url.scheme == "https")
        #expect(url.host == "example.com")
        #expect(url.port == nil)
        #expect(url.path == "")
        #expect(url.query == nil)
        #expect(url.fragment == nil)
        #expect(url.lastPathComponent == "")
    }

    @Test func rootAndTrailingSlashPaths() {
        #expect(URL(string: "https://example.com/")!.path == "/")
        #expect(URL(string: "https://example.com/")!.lastPathComponent == "/")
        #expect(URL(string: "https://example.com/dir/")!.lastPathComponent == "dir")
    }

    @Test func schemeOnlyAndRelative() {
        let mailto = URL(string: "mailto:someone@example.com")!
        #expect(mailto.scheme == "mailto")
        #expect(mailto.host == nil)
        #expect(mailto.path == "someone@example.com")

        let relative = URL(string: "docs/readme.md")!
        #expect(relative.scheme == nil)
        #expect(relative.host == nil)
        #expect(relative.path == "docs/readme.md")
        #expect(relative.lastPathComponent == "readme.md")
    }

    @Test func percentDecoding() {
        let url = URL(string: "https://example.com/hello%20world/file%2Bname")!
        #expect(url.path == "/hello world/file+name")
        #expect(url.lastPathComponent == "file+name")
        // Query stays percent-encoded.
        #expect(URL(string: "https://example.com/?q=a%20b")!.query == "q=a%20b")
    }

    @Test func ipv6Host() {
        let url = URL(string: "http://[::1]:8080/path")!
        #expect(url.host == "::1")
        #expect(url.port == 8080)
        #expect(url.path == "/path")
    }
}

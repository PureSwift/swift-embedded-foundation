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
}

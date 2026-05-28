import Testing
import Foundation
@testable import ZTPBrowser
@testable import ZTPProtocols

@Suite("URL Validation Tests")
struct URLValidationTests {

    @Test("Valid HTTP URL passes")
    func validHTTP() { #expect(URLValidator.validate(urlString: "https://example.com").valid) }

    @Test("Empty URL fails")
    func emptyURL() { #expect(!URLValidator.validate(urlString: "").valid) }

    @Test("File URL rejected")
    func fileURL() { #expect(!URLValidator.validate(urlString: "file:///etc/passwd").valid) }

    @Test("JavaScript URL rejected")
    func jsURL() { #expect(!URLValidator.validate(urlString: "javascript:alert(1)").valid) }

    @Test("No scheme fails")
    func noScheme() { #expect(!URLValidator.validate(urlString: "example.com").valid) }
}

@Suite("BrowserSpec Tests")
struct BrowserSpecTests {

    @Test("Decode spec from JSON")
    func decodeSpec() throws {
        let json = """
        {"version":"ztp-browser/0.1","task":{"action":"screenshot","url":"https://example.com","viewport":{"width":1440,"height":900}}}
        """
        let spec = try JSONDecoder().decode(BrowserSpec.self, from: Data(json.utf8))
        #expect(spec.task.action == "screenshot")
        #expect(spec.task.url == "https://example.com")
    }

    @Test("Valid spec passes validation")
    func validSpec() {
        let json = """
        {"version":"ztp-browser/0.1","task":{"action":"text","url":"https://example.com"}}
        """
        let result = BrowserSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid version fails")
    func invalidVersion() {
        let json = """
        {"version":"wrong","task":{"action":"text","url":"https://example.com"}}
        """
        let result = BrowserSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(!result.valid)
    }

    @Test("Invalid action fails")
    func invalidAction() {
        let json = """
        {"version":"ztp-browser/0.1","task":{"action":"hack","url":"https://example.com"}}
        """
        let result = BrowserSpecValidator.validate(jsonData: Data(json.utf8))
        #expect(!result.valid)
    }

    @Test("Invalid JSON fails")
    func invalidJSON() {
        #expect(!BrowserSpecValidator.validate(jsonData: Data("bad".utf8)).valid)
    }
}

@Suite("HTML Parser Tests")
struct HTMLParserTests {

    let sampleHTML = """
    <html>
    <head>
        <title>Test Page</title>
        <meta name="description" content="A test page for parsing">
        <meta property="og:title" content="OG Test">
        <link rel="canonical" href="https://example.com/canonical">
    </head>
    <body>
        <h1>Main Heading</h1>
        <p>Some paragraph text.</p>
        <h2>Sub Heading</h2>
        <a href="https://external.com">External Link</a>
        <a href="/internal">Internal Link</a>
    </body>
    </html>
    """

    @Test("Extract title")
    func title() {
        #expect(HTMLContentParser.extractTitle(from: sampleHTML) == "Test Page")
    }

    @Test("Extract meta description")
    func metaDescription() {
        #expect(HTMLContentParser.extractMetaDescription(from: sampleHTML) == "A test page for parsing")
    }

    @Test("Extract canonical URL")
    func canonical() {
        #expect(HTMLContentParser.extractCanonicalURL(from: sampleHTML) == "https://example.com/canonical")
    }

    @Test("Extract Open Graph")
    func openGraph() {
        let og = HTMLContentParser.extractOpenGraph(from: sampleHTML)
        #expect(og.title == "OG Test")
    }

    @Test("Extract headings")
    func headings() {
        let headings = HTMLContentParser.extractHeadings(from: sampleHTML)
        #expect(headings.count == 2)
        #expect(headings[0].level == 1)
        #expect(headings[0].text == "Main Heading")
    }

    @Test("Extract links")
    func links() {
        let links = HTMLContentParser.extractLinks(from: sampleHTML, baseURL: URL(string: "https://example.com"))
        #expect(links.count == 2)
        let external = links.first { $0.isExternal }
        #expect(external?.href == "https://external.com")
    }

    @Test("Extract text")
    func text() {
        let text = HTMLContentParser.extractText(from: sampleHTML)
        #expect(text.contains("Main Heading"))
        #expect(text.contains("paragraph text"))
        #expect(!text.contains("<h1>"))
    }

    @Test("Full metadata extraction")
    func metadata() {
        let meta = HTMLContentParser.extractMetadata(from: sampleHTML, baseURL: URL(string: "https://example.com"))
        #expect(meta.title == "Test Page")
        #expect(meta.headings.count == 2)
        #expect(meta.linkCount == 2)
    }
}

@Suite("HTTP Fetcher Tests")
struct HTTPFetcherTests {

    @Test("Fetch example.com")
    func fetchExample() async throws {
        let result = try await HTTPFetcher.fetch(url: URL(string: "https://example.com")!)
        #expect(result.statusCode == 200)
        #expect(result.html.contains("Example Domain"))
    }
}

@Suite("Browser Engine Tests")
struct BrowserEngineTests {

    @Test("Text extraction via engine")
    func textExtraction() async throws {
        let result = try await BrowserEngine.execute(
            action: .text, url: URL(string: "https://example.com")!,
            viewport: .desktop, timeoutMs: 10000, output: nil
        )
        #expect(result.text?.contains("Example Domain") == true)
    }

    @Test("Metadata extraction via engine")
    func metadataExtraction() async throws {
        let result = try await BrowserEngine.execute(
            action: .metadata, url: URL(string: "https://example.com")!,
            viewport: .desktop, timeoutMs: 10000, output: nil
        )
        #expect(result.metadata?.title == "Example Domain")
    }

    @Test("Links extraction via engine")
    func linksExtraction() async throws {
        let result = try await BrowserEngine.execute(
            action: .links, url: URL(string: "https://example.com")!,
            viewport: .desktop, timeoutMs: 10000, output: nil
        )
        #expect(result.links?.isEmpty == false)
    }
}

@Suite("ZTPBrowser Tool Tests")
struct ZTPBrowserToolTests {

    @Test("Manifest")
    func manifest() {
        let tool = ZTPBrowserTool()
        #expect(tool.manifest.name == "ztp-browser")
        #expect(tool.manifest.capabilities.contains("browser.screenshot"))
        #expect(tool.manifest.capabilities.contains("browser.pdf"))
        #expect(tool.manifest.capabilities.contains("browser.text"))
    }
}

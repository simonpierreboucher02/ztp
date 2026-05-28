import Testing
import Foundation
@testable import ZTPMail

@Suite("EML Generation Tests")
struct EMLTests {

    @Test("Generate basic EML")
    func basicEML() throws {
        let msg = MailMessage(
            from: MailAddress(email: "sender@test.com", name: "Sender"),
            to: [MailAddress(email: "recipient@test.com")],
            subject: "Test Email",
            body: MailBody(content: "Hello World")
        )

        let data = try EMLGenerator.generate(message: msg, basePath: nil)
        let eml = String(data: data, encoding: .utf8)!

        #expect(eml.contains("From: Sender <sender@test.com>"))
        #expect(eml.contains("To: recipient@test.com"))
        #expect(eml.contains("Subject: Test Email"))
        #expect(eml.contains("MIME-Version: 1.0"))
        #expect(eml.contains("Hello World"))
    }

    @Test("EML with signature")
    func emlWithSignature() throws {
        let msg = MailMessage(
            to: [MailAddress(email: "a@b.com")],
            subject: "S",
            body: MailBody(content: "Body"),
            signature: "-- \nJohn"
        )

        let data = try EMLGenerator.generate(message: msg, basePath: nil)
        let eml = String(data: data, encoding: .utf8)!
        #expect(eml.contains("John"))
    }

    @Test("EML round-trip inspect")
    func roundTrip() throws {
        let msg = MailMessage(
            from: MailAddress(email: "from@test.com"),
            to: [MailAddress(email: "to@test.com"), MailAddress(email: "to2@test.com")],
            cc: [MailAddress(email: "cc@test.com")],
            subject: "Round Trip",
            body: MailBody(content: "Testing round trip")
        )

        let data = try EMLGenerator.generate(message: msg, basePath: nil)
        let info = try EMLInspector.inspect(data: data)

        #expect(info.from == "from@test.com")
        #expect(info.subject == "Round Trip")
        #expect(info.to.count >= 1)
    }

    @Test("Markdown email renders HTML")
    func markdownEmail() throws {
        let msg = MailMessage(
            to: [MailAddress(email: "a@b.com")],
            subject: "S",
            body: MailBody(type: .markdown, content: "**bold** and *italic*")
        )

        let data = try EMLGenerator.generate(message: msg, basePath: nil)
        let eml = String(data: data, encoding: .utf8)!
        #expect(eml.contains("text/html"))
        #expect(eml.contains("text/plain"))
    }
}

@Suite("Mail Address Tests")
struct MailAddressTests {

    @Test("Valid email addresses")
    func validEmails() {
        #expect(MailAddress(email: "user@test.com").isValid)
        #expect(MailAddress(email: "user.name@domain.co.uk").isValid)
    }

    @Test("Invalid email addresses")
    func invalidEmails() {
        #expect(!MailAddress(email: "notanemail").isValid)
        #expect(!MailAddress(email: "@test.com").isValid)
        #expect(!MailAddress(email: "user@").isValid)
    }

    @Test("Formatted address with name")
    func formattedWithName() {
        let addr = MailAddress(email: "user@test.com", name: "John Doe")
        #expect(addr.formatted == "John Doe <user@test.com>")
    }

    @Test("Parse address string")
    func parseAddress() {
        let addr1 = MailAddress.parse("John <john@test.com>")
        #expect(addr1?.email == "john@test.com")
        #expect(addr1?.name == "John")

        let addr2 = MailAddress.parse("plain@test.com")
        #expect(addr2?.email == "plain@test.com")
    }
}

@Suite("Rendering Tests")
struct RenderingTests {

    @Test("Markdown to HTML")
    func markdownToHTML() {
        let html = MarkdownMailRenderer.render("**bold** text")
        #expect(html.contains("<strong>bold</strong>"))
    }

    @Test("Plain text rendering")
    func plainText() {
        let text = PlainTextRenderer.render(
            body: MailBody(content: "Hello"),
            signature: "-- \nJohn"
        )
        #expect(text.contains("Hello"))
        #expect(text.contains("John"))
    }

    @Test("HTML escaping")
    func htmlEscape() {
        #expect(HTMLEscaping.escape("<script>") == "&lt;script&gt;")
    }

    @Test("MIME type detection")
    func mimeDetection() {
        #expect(MailAttachment.detectMIME(for: "report.pdf") == "application/pdf")
        #expect(MailAttachment.detectMIME(for: "data.xlsx").contains("spreadsheet"))
        #expect(MailAttachment.detectMIME(for: "image.png") == "image/png")
        #expect(MailAttachment.detectMIME(for: "unknown.xyz") == "application/octet-stream")
    }
}

@Suite("ZTPMail Tool Tests")
struct ZTPMailToolTests {
    @Test("Manifest")
    func manifest() {
        let tool = ZTPMailTool()
        #expect(tool.manifest.name == "ztp-mail")
        #expect(tool.manifest.capabilities.contains("mail.validate"))
        #expect(tool.manifest.capabilities.contains("mail.draft"))
        #expect(tool.manifest.capabilities.contains("mail.send"))
    }
}

import Testing
import Foundation
@testable import ZTPMail

@Suite("Mail Inline Image Tests")
struct InlineImageTests {

    @Test("Inline images produce a multipart/related body with Content-ID")
    func relatedStructure() throws {
        let imgPath = NSTemporaryDirectory() + "ztp-inline-\(UUID().uuidString).png"
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: URL(fileURLWithPath: imgPath))
        defer { try? FileManager.default.removeItem(atPath: imgPath) }

        let msg = MailMessage(
            from: MailAddress(email: "a@x.com"),
            to: [MailAddress(email: "b@y.com")],
            subject: "Hi",
            body: MailBody(type: .html, content: "<img src=\"cid:logo\">"),
            inlineImages: [MailInlineImage(path: imgPath, cid: "logo")]
        )
        let data = try EMLGenerator.generate(message: msg, basePath: nil)
        let eml = String(data: data, encoding: .utf8) ?? ""
        #expect(eml.contains("multipart/related"))
        #expect(eml.contains("Content-ID: <logo>"))
        #expect(eml.contains("Content-Disposition: inline"))
    }

    @Test("No inline images keeps a plain multipart/alternative")
    func noInline() throws {
        let msg = MailMessage(
            to: [MailAddress(email: "b@y.com")],
            subject: "Hi",
            body: MailBody(type: .plain, content: "hello")
        )
        let eml = String(data: try EMLGenerator.generate(message: msg, basePath: nil), encoding: .utf8) ?? ""
        #expect(eml.contains("multipart/alternative"))
        #expect(!eml.contains("multipart/related"))
    }
}

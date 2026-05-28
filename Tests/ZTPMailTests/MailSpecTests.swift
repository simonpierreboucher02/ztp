import Testing
import Foundation
@testable import ZTPMail

@Suite("MailSpec Tests")
struct MailSpecTests {

    @Test("Decode complete email spec")
    func decodeSpec() throws {
        let json = """
        {
          "version": "ztp-mail/0.1",
          "message": {
            "from": "me@example.com",
            "to": ["client@example.com"],
            "subject": "Test",
            "body": { "type": "plain", "content": "Hello" }
          }
        }
        """
        let spec = try JSONDecoder().decode(MailSpec.self, from: Data(json.utf8))
        #expect(spec.version == "ztp-mail/0.1")

        let msg = try spec.toMessage()
        #expect(msg.to.count == 1)
        #expect(msg.to[0].email == "client@example.com")
        #expect(msg.subject == "Test")
        #expect(msg.body.content == "Hello")
    }

    @Test("Parse recipient as string")
    func recipientString() throws {
        let json = """
        {"version":"ztp-mail/0.1","message":{"to":["user@test.com"],"subject":"Hi","body":{"type":"plain","content":"Hey"}}}
        """
        let spec = try JSONDecoder().decode(MailSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.to[0].email == "user@test.com")
    }

    @Test("Parse recipient as object")
    func recipientObject() throws {
        let json = """
        {"version":"ztp-mail/0.1","message":{"to":[{"email":"user@test.com","name":"John"}],"subject":"Hi","body":{"type":"plain","content":"Hey"}}}
        """
        let spec = try JSONDecoder().decode(MailSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.to[0].email == "user@test.com")
        #expect(msg.to[0].name == "John")
    }

    @Test("Markdown body type")
    func markdownBody() throws {
        let json = """
        {"version":"ztp-mail/0.1","message":{"to":["a@b.com"],"subject":"S","body":{"type":"markdown","content":"**bold**"}}}
        """
        let spec = try JSONDecoder().decode(MailSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.body.type == .markdown)
    }
}

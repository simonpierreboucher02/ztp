import Testing
import Foundation
@testable import ZTPMail

@Suite("Mail Validation Tests")
struct MailValidationTests {

    @Test("Valid message passes")
    func validMessage() {
        let msg = MailMessage(
            to: [MailAddress(email: "user@test.com")],
            subject: "Test",
            body: MailBody(content: "Hello")
        )
        let result = MailValidator.validate(message: msg, basePath: nil)
        #expect(result.valid)
    }

    @Test("No recipients fails")
    func noRecipients() {
        let msg = MailMessage(to: [], subject: "Test", body: MailBody(content: "Hello"))
        let result = MailValidator.validate(message: msg, basePath: nil)
        #expect(!result.valid)
        #expect(result.errors.contains { $0.code == "NO_RECIPIENTS" })
    }

    @Test("Invalid email fails")
    func invalidEmail() {
        let msg = MailMessage(
            to: [MailAddress(email: "not-an-email")],
            subject: "Test",
            body: MailBody(content: "Hello")
        )
        let result = MailValidator.validate(message: msg, basePath: nil)
        #expect(!result.valid)
    }

    @Test("Empty subject fails")
    func emptySubject() {
        let msg = MailMessage(
            to: [MailAddress(email: "user@test.com")],
            subject: "",
            body: MailBody(content: "Hello")
        )
        let result = MailValidator.validate(message: msg, basePath: nil)
        #expect(!result.valid)
    }

    @Test("Empty body fails")
    func emptyBody() {
        let msg = MailMessage(
            to: [MailAddress(email: "user@test.com")],
            subject: "Test",
            body: MailBody(content: "")
        )
        let result = MailValidator.validate(message: msg, basePath: nil)
        #expect(!result.valid)
    }

    @Test("Valid JSON spec passes")
    func validJSON() {
        let json = """
        {"version":"ztp-mail/0.1","message":{"to":["user@test.com"],"subject":"Hi","body":{"type":"plain","content":"Hello"}}}
        """
        let result = MailValidator.validate(jsonData: Data(json.utf8), basePath: nil)
        #expect(result.valid)
    }

    @Test("Invalid JSON fails gracefully")
    func invalidJSON() {
        let result = MailValidator.validate(jsonData: Data("bad".utf8), basePath: nil)
        #expect(!result.valid)
    }
}

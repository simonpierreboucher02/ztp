import Testing
import Foundation
@testable import ZTPMessage

@Suite("SMS Validation Tests")
struct SMSValidationTests {

    private func validate(_ json: String) -> MessageValidator.ValidationResult {
        MessageValidator.validate(jsonData: Data(json.utf8))
    }

    @Test("Long SMS warns about multipart segmentation")
    func multipart() {
        let body = String(repeating: "a", count: 200)
        let r = validate("""
        {"version":"ztp-message/0.1","message":{"channel":"sms","to":[{"address":"+15551234567"}],"body":{"content":"\(body)"}}}
        """)
        #expect(r.valid)
        #expect(r.warnings.contains { $0.code == "SMS_MULTIPART" })
    }

    @Test("Email recipient on SMS channel warns")
    func emailOnSMS() {
        let r = validate("""
        {"version":"ztp-message/0.1","message":{"channel":"sms","to":[{"address":"bob@example.com"}],"body":{"content":"hi"}}}
        """)
        #expect(r.warnings.contains { $0.code == "SMS_EMAIL_RECIPIENT" })
    }

    @Test("Short iMessage has no SMS warnings")
    func cleanIMessage() {
        let r = validate("""
        {"version":"ztp-message/0.1","message":{"channel":"imessage","to":[{"address":"bob@example.com"}],"body":{"content":"hi"}}}
        """)
        #expect(r.valid)
        #expect(!r.warnings.contains { $0.code == "SMS_EMAIL_RECIPIENT" })
        #expect(!r.warnings.contains { $0.code == "SMS_MULTIPART" })
    }
}

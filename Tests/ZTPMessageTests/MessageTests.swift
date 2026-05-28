import Testing
import Foundation
@testable import ZTPMessage
@testable import ZTPProtocols

@Suite("MessageSpec Tests")
struct MessageSpecTests {

    @Test("Decode spec with string recipients")
    func decodeStringRecipients() throws {
        let json = """
        {"version":"ztp-message/0.1","message":{"channel":"imessage","to":["+14185551234"],"body":{"content":"Hello"}}}
        """
        let spec = try JSONDecoder().decode(MessageSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.to[0].address == "+14185551234")
        #expect(msg.channel == .imessage)
    }

    @Test("Decode spec with object recipients")
    func decodeObjectRecipients() throws {
        let json = """
        {"version":"ztp-message/0.1","message":{"to":[{"name":"Alex","address":"+14185551234"}],"body":{"content":"Hi"}}}
        """
        let spec = try JSONDecoder().decode(MessageSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.to[0].name == "Alex")
        #expect(msg.to[0].address == "+14185551234")
    }

    @Test("Template rendering")
    func templateRendering() throws {
        let json = """
        {"version":"ztp-message/0.1","message":{"to":["+1234"],"body":{"content":""},"template":"appointment-confirmation","variables":{"name":"Alex","date":"lundi","time":"10h"}}}
        """
        let spec = try JSONDecoder().decode(MessageSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.body.content.contains("Alex"))
        #expect(msg.body.content.contains("lundi"))
        #expect(msg.body.content.contains("10h"))
    }

    @Test("Default channel is imessage")
    func defaultChannel() throws {
        let json = """
        {"version":"ztp-message/0.1","message":{"to":["+1234"],"body":{"content":"Hi"}}}
        """
        let spec = try JSONDecoder().decode(MessageSpec.self, from: Data(json.utf8))
        let msg = try spec.toMessage()
        #expect(msg.channel == .imessage)
    }
}

@Suite("Message Validation Tests")
struct MessageValidationTests {

    @Test("Valid message passes")
    func validMessage() {
        let msg = ShortMessage(to: [MessageRecipient(address: "+14185551234")], body: MessageBody(content: "Hello"))
        let result = MessageValidator.validate(message: msg)
        #expect(result.valid)
    }

    @Test("No recipients fails")
    func noRecipients() {
        let msg = ShortMessage(to: [], body: MessageBody(content: "Hello"))
        let result = MessageValidator.validate(message: msg)
        #expect(!result.valid)
    }

    @Test("Empty body fails")
    func emptyBody() {
        let msg = ShortMessage(to: [MessageRecipient(address: "+1234")], body: MessageBody(content: ""))
        let result = MessageValidator.validate(message: msg)
        #expect(!result.valid)
    }

    @Test("Valid JSON spec")
    func validJSON() {
        let json = """
        {"version":"ztp-message/0.1","message":{"to":["+1234"],"body":{"content":"Hi"}}}
        """
        let result = MessageValidator.validate(jsonData: Data(json.utf8))
        #expect(result.valid)
    }

    @Test("Invalid JSON fails")
    func invalidJSON() {
        let result = MessageValidator.validate(jsonData: Data("bad".utf8))
        #expect(!result.valid)
    }

    @Test("Invalid version fails")
    func invalidVersion() {
        let json = """
        {"version":"wrong","message":{"to":["+1234"],"body":{"content":"Hi"}}}
        """
        let result = MessageValidator.validate(jsonData: Data(json.utf8))
        #expect(!result.valid)
    }
}

@Suite("Draft Tests")
struct DraftTests {

    @Test("Generate and inspect draft")
    func draftRoundTrip() throws {
        let msg = ShortMessage(
            channel: .imessage,
            to: [MessageRecipient(name: "Alex", address: "+14185551234")],
            body: MessageBody(content: "Test message")
        )
        let data = try DraftGenerator.generateJSON(message: msg)
        let info = try DraftInspector.inspect(data: data)

        #expect(info.channel == "imessage")
        #expect(info.recipients.count == 1)
        #expect(info.characterCount == 12)
    }

    @Test("Draft output is valid JSON")
    func draftIsJSON() throws {
        let msg = ShortMessage(to: [MessageRecipient(address: "+1234")], body: MessageBody(content: "Hi"))
        let data = try DraftGenerator.generateJSON(message: msg)
        let parsed = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        #expect(parsed != nil)
        #expect(parsed?["channel"] as? String == "imessage")
    }
}

@Suite("Template Tests")
struct TemplateTests {

    @Test("List built-in templates")
    func listTemplates() {
        let templates = MessageTemplateEngine.list()
        #expect(templates.count >= 4)
    }

    @Test("Get template by name")
    func getTemplate() {
        let t = MessageTemplateEngine.get(named: "appointment-confirmation")
        #expect(t != nil)
        #expect(t!.pattern.contains("{{name}}"))
    }

    @Test("Render template")
    func renderTemplate() throws {
        let result = try MessageTemplateEngine.render(
            template: "Bonjour {{name}}, RDV à {{time}}.",
            variables: ["name": "Alex", "time": "10h"]
        )
        #expect(result == "Bonjour Alex, RDV à 10h.")
    }

    @Test("Unknown template returns nil")
    func unknownTemplate() {
        #expect(MessageTemplateEngine.get(named: "nonexistent") == nil)
    }
}

@Suite("Recipient Tests")
struct RecipientTests {

    @Test("Phone number detection")
    func phoneNumber() {
        let r = MessageRecipient(address: "+14185551234")
        #expect(r.isPhoneNumber)
        #expect(!r.isEmail)
    }

    @Test("Email detection")
    func email() {
        let r = MessageRecipient(address: "user@test.com")
        #expect(r.isEmail)
    }

    @Test("Display name with name")
    func displayNameWithName() {
        let r = MessageRecipient(name: "Alex", address: "+1234")
        #expect(r.displayName == "Alex")
    }

    @Test("Display name without name")
    func displayNameWithoutName() {
        let r = MessageRecipient(address: "+1234")
        #expect(r.displayName == "+1234")
    }
}

@Suite("ZTPMessage Tool Tests")
struct ZTPMessageToolTests {

    @Test("Manifest")
    func manifest() {
        let tool = ZTPMessageTool()
        #expect(tool.manifest.name == "ztp-message")
        #expect(tool.manifest.capabilities.contains("message.draft"))
        #expect(tool.manifest.capabilities.contains("message.send"))
        #expect(tool.manifest.capabilities.contains("message.imessage"))
    }

    @Test("Execute without command returns error")
    func noCommand() async throws {
        let tool = ZTPMessageTool()
        let result = try await tool.execute(input: ToolInput(), context: ToolContext())
        #expect(result.ok == false)
    }
}

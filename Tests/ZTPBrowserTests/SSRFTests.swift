import Testing
import Foundation
@testable import ZTPBrowser

@Suite("SSRF Guard Tests")
struct SSRFTests {

    @Test("Blocks private and loopback hosts by default")
    func blocksPrivate() {
        for url in [
            "http://127.0.0.1/admin",
            "http://localhost:8080",
            "http://10.0.0.5/",
            "http://192.168.1.1/",
            "http://172.16.0.1/",
            "http://169.254.169.254/latest/meta-data/",
            "http://[::1]/",
        ] {
            let r = URLValidator.validate(urlString: url)
            #expect(r.valid == false, "\(url) must be blocked")
            #expect(r.errors.contains { $0.code == "BLOCKED_HOST" })
        }
    }

    @Test("Allows public hosts")
    func allowsPublic() {
        for url in ["https://example.com", "https://api.github.com/repos", "http://93.184.216.34/"] {
            #expect(URLValidator.validate(urlString: url).valid, "\(url) should be allowed")
        }
    }

    @Test("Private hosts permitted when explicitly allowed")
    func allowPrivateFlag() {
        let r = URLValidator.validate(urlString: "http://127.0.0.1/", allowPrivateHosts: true)
        #expect(r.valid)
        #expect(r.errors.contains { $0.code == "PRIVATE_HOST_WARNING" })
    }

    @Test("isBlockedHost classifies ranges")
    func ranges() {
        #expect(URLValidator.isBlockedHost("10.1.2.3"))
        #expect(URLValidator.isBlockedHost("172.31.255.1"))
        #expect(URLValidator.isBlockedHost("192.168.0.1"))
        #expect(URLValidator.isBlockedHost("100.64.0.1"))
        #expect(!URLValidator.isBlockedHost("8.8.8.8"))
        #expect(!URLValidator.isBlockedHost("example.com"))
        #expect(!URLValidator.isBlockedHost("172.32.0.1")) // outside 16-31
    }
}

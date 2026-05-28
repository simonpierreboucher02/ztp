import Foundation

public enum SMTPEncryption: String, Codable, Sendable, Equatable {
    case none
    case ssl
    case starttls
}

public struct SMTPProfile: Codable, Sendable, Equatable {
    public let name: String
    public let host: String
    public let port: Int
    public let username: String
    public let encryption: SMTPEncryption
    public let fromAddress: String?
    public let fromName: String?

    public init(
        name: String,
        host: String,
        port: Int = 587,
        username: String,
        encryption: SMTPEncryption = .starttls,
        fromAddress: String? = nil,
        fromName: String? = nil
    ) {
        self.name = name
        self.host = host
        self.port = port
        self.username = username
        self.encryption = encryption
        self.fromAddress = fromAddress
        self.fromName = fromName
    }
}

public struct SMTPConfigManager: Sendable {

    /// Path to the SMTP profiles configuration file.
    public static let configPath: String = {
        let home = ProcessInfo.processInfo.environment["HOME"] ?? NSHomeDirectory()
        return "\(home)/.ztp/mail/profiles.json"
    }()

    /// Load all SMTP profiles from the configuration file.
    ///
    /// Returns an empty array if the file does not exist.
    /// Throws if the file exists but cannot be parsed.
    public static func loadProfiles() throws -> [SMTPProfile] {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: configPath) else {
            return []
        }

        guard let data = fileManager.contents(atPath: configPath) else {
            return []
        }

        let decoder = JSONDecoder()
        return try decoder.decode([SMTPProfile].self, from: data)
    }

    /// Find a profile by name.
    ///
    /// Returns `nil` if no profile with that name exists.
    public static func profile(named name: String) throws -> SMTPProfile? {
        let profiles = try loadProfiles()
        return profiles.first { $0.name == name }
    }
}

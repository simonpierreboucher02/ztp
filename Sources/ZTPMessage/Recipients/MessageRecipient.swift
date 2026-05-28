import Foundation

public struct MessageRecipient: Codable, Sendable, Equatable {
    public let name: String?
    public let address: String

    public init(name: String? = nil, address: String) {
        self.name = name
        self.address = address
    }

    public var displayName: String {
        name ?? address
    }

    public var isPhoneNumber: Bool {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("+") {
            let digits = trimmed.dropFirst()
            return !digits.isEmpty && digits.allSatisfy { $0.isNumber }
        }
        return trimmed.allSatisfy { $0.isNumber }
    }

    public var isEmail: Bool {
        let trimmed = address.trimmingCharacters(in: .whitespaces)
        guard let atIndex = trimmed.firstIndex(of: "@") else { return false }
        let local = trimmed[trimmed.startIndex..<atIndex]
        let domain = trimmed[trimmed.index(after: atIndex)...]
        return !local.isEmpty && domain.contains(".")
    }
}

import Foundation

public struct MailAttachment: Codable, Sendable, Equatable {
    public let path: String
    public let name: String?
    public let mimeType: String?

    public init(path: String, name: String? = nil, mimeType: String? = nil) {
        self.path = path
        self.name = name
        self.mimeType = mimeType
    }

    /// Returns the explicit name if set, otherwise the last path component.
    public var displayName: String {
        if let name = name, !name.isEmpty {
            return name
        }
        // Extract last path component
        if let lastSlash = path.lastIndex(of: "/") {
            let afterSlash = path[path.index(after: lastSlash)...]
            if !afterSlash.isEmpty {
                return String(afterSlash)
            }
        }
        return path
    }

    /// Detect MIME type from a file extension.
    public static func detectMIME(for path: String) -> String {
        let lowered = path.lowercased()
        let ext: String
        if let dotIndex = lowered.lastIndex(of: ".") {
            ext = String(lowered[lowered.index(after: dotIndex)...])
        } else {
            ext = ""
        }

        switch ext {
        case "pdf":
            return "application/pdf"
        case "xlsx":
            return "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        case "docx":
            return "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
        case "pptx":
            return "application/vnd.openxmlformats-officedocument.presentationml.presentation"
        case "png":
            return "image/png"
        case "jpg", "jpeg":
            return "image/jpeg"
        case "gif":
            return "image/gif"
        case "csv":
            return "text/csv"
        case "zip":
            return "application/zip"
        case "txt":
            return "text/plain"
        default:
            return "application/octet-stream"
        }
    }
}

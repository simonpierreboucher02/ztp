import Foundation

public enum ToolError: Error, Sendable {
    case invalidInput(String)
    case executionFailed(String)
    case timeout
    case notFound(String)
    case permissionDenied(String)
    case internalError(String)
}

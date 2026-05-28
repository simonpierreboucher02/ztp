import Foundation

public enum ZTPError: Error, Sendable {
    case toolNotFound(String)
    case manifestInvalid(String)
    case schemaValidationFailed(String)
    case runtimeNotInitialized
    case configurationError(String)
}

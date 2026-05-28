import Foundation

public struct ToolContext: Sendable {
    public let workingDirectory: URL
    public let environment: [String: String]
    public let traceID: String

    public init(
        workingDirectory: URL = URL(fileURLWithPath: FileManager.default.currentDirectoryPath),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        traceID: String = UUID().uuidString
    ) {
        self.workingDirectory = workingDirectory
        self.environment = environment
        self.traceID = traceID
    }
}

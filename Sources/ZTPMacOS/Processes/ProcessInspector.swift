import Foundation

// MARK: - ProcessInspector

public struct ProcessInspector: Sendable {

    // MARK: - Models

    /// Process information (named with trailing underscore to avoid conflict with Foundation.ProcessInfo).
    public struct ProcessInfo_: Codable, Sendable {
        public let name: String
        public let pid: Int
        public let cpu: Double
        public let memory: Double  // MB
        public let user: String
    }

    // MARK: - Public API

    /// Lists all running processes with CPU, memory, and user info.
    public static func list() -> [ProcessInfo_] {
        return parseProcessList(filter: nil)
    }

    /// Lists processes matching the given name (case-insensitive partial match).
    public static func inspect(name: String) -> [ProcessInfo_] {
        return parseProcessList(filter: name)
    }

    // MARK: - Parsing

    private static func parseProcessList(filter: String?) -> [ProcessInfo_] {
        // ps output format: PID %CPU RSS USER COMMAND
        let output = shellOutput("ps -eo pid=,pcpu=,rss=,user=,comm=")
        let lines = output.components(separatedBy: "\n")

        var results: [ProcessInfo_] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            // Split into components — the command may contain spaces
            let parts = trimmed.split(maxSplits: 4, omittingEmptySubsequences: true) { $0.isWhitespace }
            guard parts.count >= 5 else { continue }

            guard let pid = Int(parts[0]) else { continue }
            let cpu = Double(parts[1]) ?? 0.0
            let rssKB = Double(parts[2]) ?? 0.0
            let memoryMB = rssKB / 1024.0
            let user = String(parts[3])
            let comm = String(parts[4])

            // Extract the process name from the full path
            let name = (comm as NSString).lastPathComponent

            // Apply filter if provided
            if let filter = filter {
                guard name.localizedCaseInsensitiveContains(filter) else { continue }
            }

            results.append(ProcessInfo_(
                name: name,
                pid: pid,
                cpu: (cpu * 100).rounded() / 100,
                memory: (memoryMB * 100).rounded() / 100,
                user: user
            ))
        }

        // Sort by CPU descending
        return results.sorted { $0.cpu > $1.cpu }
    }
}

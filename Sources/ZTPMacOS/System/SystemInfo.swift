import Foundation

// MARK: - SystemInfo

public struct SystemInfo: Sendable {

    // MARK: - Models

    public struct Info: Codable, Sendable {
        public let hostname: String
        public let macosVersion: String
        public let buildVersion: String
        public let chip: String
        public let cores: Int
        public let memoryGB: Int
        public let serialNumber: String?
    }

    public struct DiskInfo: Codable, Sendable {
        public let name: String
        public let mountPoint: String
        public let totalGB: Double
        public let freeGB: Double
        public let usedPercent: Double
    }

    public struct MemoryInfo: Codable, Sendable {
        public let totalGB: Int
        public let activeProcesses: Int
    }

    public struct BatteryInfo: Codable, Sendable {
        public let hasBattery: Bool
        public let percentage: Int?
        public let isCharging: Bool?
        public let powerSource: String?
    }

    // MARK: - Public API

    public static func info() -> Info {
        let processInfo = ProcessInfo.processInfo
        let version = processInfo.operatingSystemVersion
        let macosVersion = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"

        let buildVersion = shellOutput("sw_vers -buildVersion").trimmingCharacters(in: .whitespacesAndNewlines)
        let chip = shellOutput("sysctl -n machdep.cpu.brand_string").trimmingCharacters(in: .whitespacesAndNewlines)
        let cores = processInfo.processorCount
        let memoryGB = Int(processInfo.physicalMemory / (1024 * 1024 * 1024))
        let hostname = processInfo.hostName

        var serialNumber: String? = nil
        let serialRaw = shellOutput("ioreg -l | grep IOPlatformSerialNumber")
        if let range = serialRaw.range(of: "\"IOPlatformSerialNumber\" = \"") {
            let rest = serialRaw[range.upperBound...]
            if let end = rest.firstIndex(of: "\"") {
                serialNumber = String(rest[..<end])
            }
        }

        return Info(
            hostname: hostname,
            macosVersion: macosVersion,
            buildVersion: buildVersion,
            chip: chip.isEmpty ? "Unknown" : chip,
            cores: cores,
            memoryGB: memoryGB,
            serialNumber: serialNumber
        )
    }

    public static func disks() -> [DiskInfo] {
        var results: [DiskInfo] = []

        // Root volume via FileManager
        let fm = FileManager.default
        if let attrs = try? fm.attributesOfFileSystem(forPath: "/") {
            let totalBytes = (attrs[.systemSize] as? Int64) ?? 0
            let freeBytes = (attrs[.systemFreeSize] as? Int64) ?? 0
            let totalGB = Double(totalBytes) / 1_000_000_000.0
            let freeGB = Double(freeBytes) / 1_000_000_000.0
            let usedPercent = totalGB > 0 ? ((totalGB - freeGB) / totalGB) * 100.0 : 0.0
            results.append(DiskInfo(
                name: "Macintosh HD",
                mountPoint: "/",
                totalGB: (totalGB * 100).rounded() / 100,
                freeGB: (freeGB * 100).rounded() / 100,
                usedPercent: (usedPercent * 100).rounded() / 100
            ))
        }

        // Additional volumes in /Volumes
        if let volumes = try? fm.contentsOfDirectory(atPath: "/Volumes") {
            for volume in volumes {
                let mountPoint = "/Volumes/\(volume)"
                // Skip symlinks that point back to root
                if let dest = try? fm.destinationOfSymbolicLink(atPath: mountPoint), dest == "/" {
                    continue
                }
                guard let attrs = try? fm.attributesOfFileSystem(forPath: mountPoint) else { continue }
                let totalBytes = (attrs[.systemSize] as? Int64) ?? 0
                let freeBytes = (attrs[.systemFreeSize] as? Int64) ?? 0
                let totalGB = Double(totalBytes) / 1_000_000_000.0
                let freeGB = Double(freeBytes) / 1_000_000_000.0
                guard totalGB > 0 else { continue }
                let usedPercent = ((totalGB - freeGB) / totalGB) * 100.0
                results.append(DiskInfo(
                    name: volume,
                    mountPoint: mountPoint,
                    totalGB: (totalGB * 100).rounded() / 100,
                    freeGB: (freeGB * 100).rounded() / 100,
                    usedPercent: (usedPercent * 100).rounded() / 100
                ))
            }
        }

        return results
    }

    public static func memory() -> MemoryInfo {
        let totalGB = Int(ProcessInfo.processInfo.physicalMemory / (1024 * 1024 * 1024))
        let psOutput = shellOutput("ps aux | wc -l").trimmingCharacters(in: .whitespacesAndNewlines)
        let activeProcesses = max(0, (Int(psOutput) ?? 1) - 1) // subtract header line
        return MemoryInfo(totalGB: totalGB, activeProcesses: activeProcesses)
    }

    public static func battery() -> BatteryInfo {
        let output = shellOutput("pmset -g batt")
        guard !output.isEmpty else {
            return BatteryInfo(hasBattery: false, percentage: nil, isCharging: nil, powerSource: nil)
        }

        // Parse power source from first line: "Now drawing from 'AC Power'"
        var powerSource: String? = nil
        let lines = output.components(separatedBy: "\n")
        if let firstLine = lines.first, let quoteStart = firstLine.range(of: "'") {
            let rest = firstLine[quoteStart.upperBound...]
            if let quoteEnd = rest.firstIndex(of: "'") {
                powerSource = String(rest[..<quoteEnd])
            }
        }

        // Parse battery percentage and charging state from second line
        // e.g. "-InternalBattery-0 (id=...)	85%; charging; 1:23 remaining"
        var hasBattery = false
        var percentage: Int? = nil
        var isCharging: Bool? = nil

        for line in lines.dropFirst() {
            if line.contains("InternalBattery") {
                hasBattery = true
                // Extract percentage
                if let pctRange = line.range(of: #"(\d+)%"#, options: .regularExpression) {
                    let pctStr = line[pctRange].dropLast() // remove %
                    percentage = Int(pctStr)
                }
                // Charging state
                let lower = line.lowercased()
                if lower.contains("charging") && !lower.contains("not charging") && !lower.contains("discharging") {
                    isCharging = true
                } else {
                    isCharging = false
                }
                break
            }
        }

        return BatteryInfo(
            hasBattery: hasBattery,
            percentage: percentage,
            isCharging: isCharging,
            powerSource: powerSource
        )
    }
}

// MARK: - Shell Helper (internal)

func shellOutput(_ command: String) -> String {
    let process = Process()
    let pipe = Pipe()
    process.executableURL = URL(fileURLWithPath: "/bin/bash")
    process.arguments = ["-c", command]
    process.standardOutput = pipe
    process.standardError = Pipe()
    do {
        try process.run()
        process.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    } catch {
        return ""
    }
}

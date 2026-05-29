import Testing
import Foundation

/// Integration tests for the generic ZTP runtime CLI (tools / run / schema /
/// inspect / validate), driving the real `ztp` binary.
@Suite("Runtime CLI Tests")
struct RuntimeCLITests {

    // MARK: - Helpers

    private func binaryPath() -> String {
        // .build/debug/ztp relative to the package root.
        let root = packageRoot()
        return root.appendingPathComponent(".build/debug/ztp").path
    }

    private func packageRoot() -> URL {
        // This file: <root>/Tests/ZTPCLITests/RuntimeTests.swift
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private struct Run { let status: Int32; let out: String }

    private func run(_ args: [String], stdin: Data? = nil) throws -> Run {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: binaryPath())
        p.arguments = args
        p.currentDirectoryURL = packageRoot()
        let outPipe = Pipe()
        p.standardOutput = outPipe
        p.standardError = outPipe
        let inPipe = Pipe()
        p.standardInput = inPipe
        try p.run()
        if let stdin { inPipe.fileHandleForWriting.write(stdin) }
        inPipe.fileHandleForWriting.closeFile()
        p.waitUntilExit()
        let data = outPipe.fileHandleForReading.readDataToEndOfFile()
        return Run(status: p.terminationStatus, out: String(data: data, encoding: .utf8) ?? "")
    }

    private func requireBinary() -> Bool {
        FileManager.default.isExecutableFile(atPath: binaryPath())
    }

    // MARK: - tools

    @Test("ztp tools --json lists all 8 built-in tools")
    func toolsList() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let r = try run(["tools", "--json"])
        #expect(r.status == 0)
        #expect(r.out.contains("\"count\" : 8"))
        for name in ["ztp-excel", "ztp-docx", "ztp-slides", "ztp-chart", "ztp-mail", "ztp-message", "ztp-browser", "ztp-macos"] {
            #expect(r.out.contains(name), "tools should include \(name)")
        }
    }

    // MARK: - schema / inspect

    @Test("ztp schema excel emits JSON with commands")
    func schemaExcel() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let r = try run(["schema", "excel"])
        #expect(r.status == 0)
        #expect(r.out.contains("\"commands\""))
        #expect(r.out.contains("\"build\""))
        // valid JSON
        #expect((try? JSONSerialization.jsonObject(with: Data(r.out.utf8))) != nil)
    }

    @Test("ztp inspect resolves short and canonical names")
    func inspectNames() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let short = try run(["inspect", "chart"])
        let canonical = try run(["inspect", "ztp-chart"])
        #expect(short.status == 0)
        #expect(canonical.status == 0)
        #expect(short.out.contains("ztp-chart"))
    }

    // MARK: - run

    @Test("ztp run excel build produces an XLSX")
    func runExcelBuild() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let out = NSTemporaryDirectory() + "ztp-rt-\(UUID().uuidString).xlsx"
        defer { try? FileManager.default.removeItem(atPath: out) }
        let input = "{\"command\":\"build\",\"input\":\"Examples/excel/simple-workbook.json\",\"output\":\"\(out)\"}"
        let r = try run(["run", "excel", "--json"], stdin: Data(input.utf8))
        #expect(r.status == 0)
        #expect(r.out.contains("\"ok\" : true"))
        #expect(FileManager.default.fileExists(atPath: out), "XLSX should be created")
    }

    @Test("ztp run surfaces tool failures with nonzero exit")
    func runFailurePropagates() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        // build with no input → MISSING_INPUT, must exit nonzero (runtime must
        // not mask the tool's failure as success).
        let r = try run(["run", "excel", "--command", "build"], stdin: Data())
        #expect(r.status != 0)
        #expect(r.out.contains("MISSING_INPUT"))
    }

    @Test("ztp run rejects unknown tools")
    func runUnknownTool() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let r = try run(["run", "does-not-exist", "--command", "x"], stdin: Data())
        #expect(r.status != 0)
        #expect(r.out.contains("Unknown tool"))
    }

    // MARK: - validate

    @Test("ztp validate passes a real spec and fails a broken one")
    func validateSpecs() throws {
        guard requireBinary() else { Issue.record("binary missing"); return }
        let good = try run(["validate", "excel", "Examples/excel/simple-workbook.json"])
        #expect(good.status == 0)

        let badPath = NSTemporaryDirectory() + "ztp-bad-\(UUID().uuidString).json"
        try "{\"version\":\"wrong\"}".write(toFile: badPath, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(atPath: badPath) }
        let bad = try run(["validate", "excel", badPath])
        #expect(bad.status != 0)
    }
}

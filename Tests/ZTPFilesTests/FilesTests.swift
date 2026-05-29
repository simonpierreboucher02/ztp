import Testing
import Foundation
@testable import ZTPFiles

@Suite("ZTPFiles Tests")
struct ZTPFilesTests {

    private func tempDir() throws -> String {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("ztp-files-test-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.path
    }

    @Test("Manifest name + capabilities")
    func manifest() {
        let tool = ZTPFilesTool()
        #expect(tool.manifest.name == "ztp-files")
        #expect(tool.manifest.capabilities.contains("search"))
        #expect(tool.manifest.capabilities.contains("compress"))
    }

    @Test("List, mkdir, info")
    func listMkdir() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        _ = try FilesEngine.mkdir(path: "\(root)/sub")
        try "hello".write(toFile: "\(root)/a.txt", atomically: true, encoding: .utf8)

        let entries = try FilesEngine.list(path: root, includeHidden: false, sort: .name)
        #expect(entries.count == 2)
        #expect(entries.contains { $0.name == "a.txt" && !$0.isDirectory })
        #expect(entries.contains { $0.name == "sub" && $0.isDirectory })

        let info = try FilesEngine.info(path: "\(root)/a.txt")
        #expect(info.size == 5)
        #expect(info.ext == "txt")
    }

    @Test("Search by name and content")
    func search() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try "needle here".write(toFile: "\(root)/report.txt", atomically: true, encoding: .utf8)
        try "nothing".write(toFile: "\(root)/other.md", atomically: true, encoding: .utf8)

        let byName = try FilesEngine.search(path: root, query: "report", regex: false, searchContent: false, ext: nil, maxResults: 50, includeHidden: false)
        #expect(byName.contains { $0.name == "report.txt" })

        let byContent = try FilesEngine.search(path: root, query: "needle", regex: false, searchContent: true, ext: nil, maxResults: 50, includeHidden: false)
        #expect(byContent.contains { $0.name == "report.txt" && !$0.lineMatches.isEmpty })
    }

    @Test("Copy, rename, delete")
    func copyRenameDelete() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        try "x".write(toFile: "\(root)/src.txt", atomically: true, encoding: .utf8)

        _ = try FilesEngine.copy(from: "\(root)/src.txt", to: "\(root)/copy.txt")
        #expect(FileManager.default.fileExists(atPath: "\(root)/copy.txt"))

        let renamed = try FilesEngine.rename(path: "\(root)/copy.txt", newName: "renamed.txt", confirmed: true)
        #expect(renamed.success)
        #expect(FileManager.default.fileExists(atPath: "\(root)/renamed.txt"))

        // delete requires confirmation
        #expect(throws: (any Error).self) {
            _ = try FilesEngine.delete(path: "\(root)/renamed.txt", confirmed: false, permanent: true)
        }
        _ = try FilesEngine.delete(path: "\(root)/renamed.txt", confirmed: true, permanent: true)
        #expect(!FileManager.default.fileExists(atPath: "\(root)/renamed.txt"))
    }

    @Test("Compress then extract round-trips")
    func compressExtract() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        _ = try FilesEngine.mkdir(path: "\(root)/payload")
        try "data".write(toFile: "\(root)/payload/file.txt", atomically: true, encoding: .utf8)

        let zip = "\(root)/out.zip"
        let r = try FilesEngine.compress(path: "\(root)/payload", output: zip)
        #expect(r.success)
        #expect(FileManager.default.fileExists(atPath: zip))

        _ = try FilesEngine.extract(input: zip, to: "\(root)/unzipped", confirmed: true)
        #expect(FileManager.default.fileExists(atPath: "\(root)/unzipped/payload/file.txt"))
    }

    @Test("Tree respects depth")
    func tree() throws {
        let root = try tempDir()
        defer { try? FileManager.default.removeItem(atPath: root) }
        _ = try FilesEngine.mkdir(path: "\(root)/a/b/c")
        let shallow = try FilesEngine.tree(path: root, maxDepth: 1, maxEntries: 100, includeHidden: false)
        #expect(shallow.allSatisfy { $0.depth <= 1 })
    }
}

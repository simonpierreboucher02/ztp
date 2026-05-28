// DocxZIPReader.swift
// ZTPDocx – Minimal ZIP archive reader for .docx inspection.

import Foundation
import Compression

// MARK: - Errors

enum DocxZIPReaderError: Error, Sendable {
    case invalidArchive
    case endOfCentralDirectoryNotFound
    case invalidEntry
    case decompressionFailed
    case dataTooSmall
}

// MARK: - DocxZIPReader

/// A minimal ZIP reader that parses end-of-central-directory, central directory
/// entries, and extracts file data from local file headers.
///
/// Supports stored (method 0) and deflated (method 8) entries.
/// Uses byte-by-byte reads to avoid alignment crashes.
struct DocxZIPReader: Sendable {

    /// A single file entry extracted from the ZIP archive.
    struct Entry: Sendable {
        let path: String
        let data: Data
    }

    // MARK: - ZIP signatures

    private static let eocdSignature: UInt32 = 0x06054B50
    private static let centralDirSignature: UInt32 = 0x02014B50
    private static let localFileSignature: UInt32 = 0x04034B50

    // MARK: - Public API

    /// Reads all entries from a ZIP archive stored in `data`.
    ///
    /// - Parameter data: The raw bytes of the ZIP file.
    /// - Returns: An array of ``Entry`` values with their paths and decompressed data.
    static func readEntries(from data: Data) throws -> [Entry] {
        guard data.count >= 22 else {
            throw DocxZIPReaderError.dataTooSmall
        }

        // 1. Find End of Central Directory record (scan backwards).
        let eocdOffset = try findEOCD(in: data)

        // 2. Parse EOCD to get central directory offset and entry count.
        let (cdOffset, entryCount) = try parseEOCD(data: data, eocdOffset: eocdOffset)

        // 3. Walk the central directory entries.
        var entries: [Entry] = []
        var offset = cdOffset

        for _ in 0..<entryCount {
            let (fileName, localHeaderOffset, nextOffset) = try parseCentralDirectoryEntry(
                data: data, offset: offset
            )
            offset = nextOffset

            // 4. Read the file data from the local file header.
            let fileData = try readLocalFile(data: data, offset: localHeaderOffset)

            entries.append(Entry(path: fileName, data: fileData))
        }

        return entries
    }

    // MARK: - EOCD

    /// Scans backwards to find the End of Central Directory signature.
    private static func findEOCD(in data: Data) throws -> Int {
        // EOCD is at least 22 bytes. The comment can be up to 65535 bytes.
        let minOffset = max(0, data.count - 65557)

        for i in stride(from: data.count - 22, through: minOffset, by: -1) {
            let sig = readUInt32(data: data, offset: i)
            if sig == eocdSignature {
                return i
            }
        }

        throw DocxZIPReaderError.endOfCentralDirectoryNotFound
    }

    /// Parses the EOCD record to extract the central directory offset and total entry count.
    private static func parseEOCD(data: Data, eocdOffset: Int) throws -> (cdOffset: Int, entryCount: Int) {
        // Offset 10: total entries (2 bytes)
        let totalEntries = Int(readUInt16(data: data, offset: eocdOffset + 10))
        // Offset 16: central directory offset (4 bytes)
        let cdOffset = Int(readUInt32(data: data, offset: eocdOffset + 16))

        guard cdOffset >= 0 && cdOffset < data.count else {
            throw DocxZIPReaderError.invalidArchive
        }

        return (cdOffset, totalEntries)
    }

    // MARK: - Central Directory

    /// Parses one central directory entry starting at `offset`.
    ///
    /// Returns the file name, the offset of its local file header, and
    /// the offset of the next central directory entry.
    private static func parseCentralDirectoryEntry(
        data: Data, offset: Int
    ) throws -> (fileName: String, localHeaderOffset: Int, nextOffset: Int) {
        guard offset + 46 <= data.count else {
            throw DocxZIPReaderError.invalidEntry
        }

        let sig = readUInt32(data: data, offset: offset)
        guard sig == centralDirSignature else {
            throw DocxZIPReaderError.invalidEntry
        }

        let fileNameLength = Int(readUInt16(data: data, offset: offset + 28))
        let extraFieldLength = Int(readUInt16(data: data, offset: offset + 30))
        let fileCommentLength = Int(readUInt16(data: data, offset: offset + 32))
        let localHeaderOffset = Int(readUInt32(data: data, offset: offset + 42))

        guard offset + 46 + fileNameLength <= data.count else {
            throw DocxZIPReaderError.invalidEntry
        }

        let fileNameData = data.subdata(in: (offset + 46)..<(offset + 46 + fileNameLength))
        let fileName = String(data: fileNameData, encoding: .utf8) ?? ""

        let nextOffset = offset + 46 + fileNameLength + extraFieldLength + fileCommentLength

        return (fileName, localHeaderOffset, nextOffset)
    }

    // MARK: - Local File Header

    /// Reads and decompresses file data from a local file header at `offset`.
    private static func readLocalFile(data: Data, offset: Int) throws -> Data {
        guard offset + 30 <= data.count else {
            throw DocxZIPReaderError.invalidEntry
        }

        let sig = readUInt32(data: data, offset: offset)
        guard sig == localFileSignature else {
            throw DocxZIPReaderError.invalidEntry
        }

        let compressionMethod = readUInt16(data: data, offset: offset + 8)
        let compressedSize = Int(readUInt32(data: data, offset: offset + 18))
        let uncompressedSize = Int(readUInt32(data: data, offset: offset + 22))
        let fileNameLength = Int(readUInt16(data: data, offset: offset + 26))
        let extraFieldLength = Int(readUInt16(data: data, offset: offset + 28))

        let dataStart = offset + 30 + fileNameLength + extraFieldLength
        let dataEnd = dataStart + compressedSize

        guard dataEnd <= data.count else {
            throw DocxZIPReaderError.invalidEntry
        }

        let compressedData = data.subdata(in: dataStart..<dataEnd)

        switch compressionMethod {
        case 0:
            // Stored — no compression
            return compressedData
        case 8:
            // Deflated — use Compression framework (raw deflate)
            return try decompressDeflate(compressedData, uncompressedSize: uncompressedSize)
        default:
            throw DocxZIPReaderError.invalidEntry
        }
    }

    // MARK: - Decompression

    /// Decompresses raw DEFLATE data using the Compression framework.
    private static func decompressDeflate(_ compressedData: Data, uncompressedSize: Int) throws -> Data {
        // Allocate a buffer for the output.
        let bufferSize = max(uncompressedSize, compressedData.count * 4)

        let decompressed: Data = try compressedData.withUnsafeBytes { rawBuffer -> Data in
            guard let srcPointer = rawBuffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
                throw DocxZIPReaderError.decompressionFailed
            }

            let dstBuffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { dstBuffer.deallocate() }

            let decodedSize = compression_decode_buffer(
                dstBuffer, bufferSize,
                srcPointer, compressedData.count,
                nil,
                COMPRESSION_ZLIB
            )

            guard decodedSize > 0 else {
                throw DocxZIPReaderError.decompressionFailed
            }

            return Data(bytes: dstBuffer, count: decodedSize)
        }

        return decompressed
    }

    // MARK: - Binary helpers (byte-by-byte to avoid alignment crashes)

    private static func readUInt16(data: Data, offset: Int) -> UInt16 {
        let b0 = UInt16(data[data.startIndex + offset])
        let b1 = UInt16(data[data.startIndex + offset + 1])
        return b0 | (b1 << 8)
    }

    private static func readUInt32(data: Data, offset: Int) -> UInt32 {
        let b0 = UInt32(data[data.startIndex + offset])
        let b1 = UInt32(data[data.startIndex + offset + 1])
        let b2 = UInt32(data[data.startIndex + offset + 2])
        let b3 = UInt32(data[data.startIndex + offset + 3])
        return b0 | (b1 << 8) | (b2 << 16) | (b3 << 24)
    }
}

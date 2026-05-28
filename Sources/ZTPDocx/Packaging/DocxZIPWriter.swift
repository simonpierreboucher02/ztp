// DocxZIPWriter.swift
// ZTPDocx – Minimal ZIP archive writer (stored method, no compression)

import Foundation

/// A self-contained ZIP file writer that creates valid ZIP archives
/// using the stored (no compression) method.
///
/// This avoids external dependencies while producing archives that
/// any standard ZIP tool and Word can open.
struct DocxZIPWriter: Sendable {

    /// A single file entry in the archive.
    struct Entry: Sendable {
        /// The relative path inside the archive (e.g. "word/document.xml").
        let path: String
        /// The raw file data.
        let data: Data
    }

    /// Errors that can occur during archive creation.
    enum ZIPError: Error, Sendable {
        case encodingError
    }

    /// Creates a valid ZIP archive from the given entries.
    ///
    /// Uses compression method 0 (stored) — data is included verbatim,
    /// which is sufficient for XML content and keeps the implementation
    /// minimal.
    ///
    /// - Parameter entries: The files to include.
    /// - Returns: The raw bytes of the complete ZIP file.
    /// - Throws: ``ZIPError/encodingError`` if a file path cannot be
    ///   encoded to UTF-8.
    static func createArchive(entries: [Entry]) throws -> Data {
        var archive = Data()

        struct CentralEntry {
            let localHeaderOffset: UInt32
            let crc32: UInt32
            let size: UInt32
            let pathData: Data
        }

        var centralEntries: [CentralEntry] = []

        // ---- Local file headers + file data ----

        for entry in entries {
            guard let pathData = entry.path.data(using: .utf8) else {
                throw ZIPError.encodingError
            }

            let crc = DocxCRC32.calculate(entry.data)
            let size = UInt32(entry.data.count)
            let localOffset = UInt32(archive.count)

            centralEntries.append(CentralEntry(
                localHeaderOffset: localOffset,
                crc32: crc,
                size: size,
                pathData: pathData
            ))

            // Local file header
            archive.docxAppendUInt32(0x04034b50)       // signature
            archive.docxAppendUInt16(20)               // version needed (2.0)
            archive.docxAppendUInt16(0)                 // general purpose flags
            archive.docxAppendUInt16(0)                 // compression method (stored)
            archive.docxAppendUInt16(0)                 // last mod file time
            archive.docxAppendUInt16(0)                 // last mod file date
            archive.docxAppendUInt32(crc)               // CRC-32
            archive.docxAppendUInt32(size)              // compressed size
            archive.docxAppendUInt32(size)              // uncompressed size
            archive.docxAppendUInt16(UInt16(pathData.count)) // file name length
            archive.docxAppendUInt16(0)                 // extra field length
            archive.append(pathData)                    // file name
            archive.append(entry.data)                  // file data
        }

        // ---- Central directory ----

        let centralDirOffset = UInt32(archive.count)

        for ce in centralEntries {
            archive.docxAppendUInt32(0x02014b50)       // signature
            archive.docxAppendUInt16(20)               // version made by
            archive.docxAppendUInt16(20)               // version needed
            archive.docxAppendUInt16(0)                 // flags
            archive.docxAppendUInt16(0)                 // compression method
            archive.docxAppendUInt16(0)                 // last mod time
            archive.docxAppendUInt16(0)                 // last mod date
            archive.docxAppendUInt32(ce.crc32)          // CRC-32
            archive.docxAppendUInt32(ce.size)           // compressed size
            archive.docxAppendUInt32(ce.size)           // uncompressed size
            archive.docxAppendUInt16(UInt16(ce.pathData.count)) // name length
            archive.docxAppendUInt16(0)                 // extra field length
            archive.docxAppendUInt16(0)                 // comment length
            archive.docxAppendUInt16(0)                 // disk number start
            archive.docxAppendUInt16(0)                 // internal file attributes
            archive.docxAppendUInt32(0)                 // external file attributes
            archive.docxAppendUInt32(ce.localHeaderOffset) // relative offset
            archive.append(ce.pathData)                 // file name
        }

        let centralDirSize = UInt32(archive.count) - centralDirOffset

        // ---- End of central directory record ----

        archive.docxAppendUInt32(0x06054b50)           // signature
        archive.docxAppendUInt16(0)                     // disk number
        archive.docxAppendUInt16(0)                     // disk with central dir
        archive.docxAppendUInt16(UInt16(entries.count)) // entries on this disk
        archive.docxAppendUInt16(UInt16(entries.count)) // total entries
        archive.docxAppendUInt32(centralDirSize)        // central dir size
        archive.docxAppendUInt32(centralDirOffset)      // central dir offset
        archive.docxAppendUInt16(0)                     // comment length

        return archive
    }
}

// MARK: - Data helpers for little-endian integer writing

private extension Data {
    mutating func docxAppendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func docxAppendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}

// MARK: - CRC32

/// Standard CRC-32 implementation using the IEEE 802.3 polynomial.
enum DocxCRC32: Sendable {

    /// Precomputed lookup table for the CRC-32 polynomial 0xEDB88320.
    private static let table: [UInt32] = {
        (0..<256).map { i -> UInt32 in
            var crc = UInt32(i)
            for _ in 0..<8 {
                if crc & 1 == 1 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
            return crc
        }
    }()

    /// Computes the CRC-32 checksum of the given data.
    static func calculate(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        data.withUnsafeBytes { buffer in
            guard let bytes = buffer.baseAddress?.assumingMemoryBound(to: UInt8.self) else { return }
            for i in 0..<buffer.count {
                let index = Int((crc ^ UInt32(bytes[i])) & 0xFF)
                crc = (crc >> 8) ^ table[index]
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}

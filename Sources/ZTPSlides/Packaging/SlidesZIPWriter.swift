// SlidesZIPWriter.swift
// ZTPSlides – Minimal ZIP archive writer (stored method, no compression)

import Foundation

/// A self-contained ZIP file writer that creates valid ZIP archives
/// using the stored (no compression) method.
///
/// This avoids external dependencies while producing archives that
/// any standard ZIP tool and PowerPoint can open.
///
/// Prefixed with `Slides` to avoid symbol collisions with the
/// identically-structured writers in ZTPExcel and ZTPDocx.
struct SlidesZIPWriter: Sendable {

    /// A single file entry in the archive.
    struct Entry: Sendable {
        /// The relative path inside the archive (e.g. "ppt/presentation.xml").
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

            let crc = SlidesCRC32.calculate(entry.data)
            let size = UInt32(entry.data.count)
            let localOffset = UInt32(archive.count)

            centralEntries.append(CentralEntry(
                localHeaderOffset: localOffset,
                crc32: crc,
                size: size,
                pathData: pathData
            ))

            // Local file header
            archive.slidesAppendUInt32(0x04034b50)       // signature
            archive.slidesAppendUInt16(20)               // version needed (2.0)
            archive.slidesAppendUInt16(0)                 // general purpose flags
            archive.slidesAppendUInt16(0)                 // compression method (stored)
            archive.slidesAppendUInt16(0)                 // last mod file time
            archive.slidesAppendUInt16(0)                 // last mod file date
            archive.slidesAppendUInt32(crc)               // CRC-32
            archive.slidesAppendUInt32(size)              // compressed size
            archive.slidesAppendUInt32(size)              // uncompressed size
            archive.slidesAppendUInt16(UInt16(pathData.count)) // file name length
            archive.slidesAppendUInt16(0)                 // extra field length
            archive.append(pathData)                      // file name
            archive.append(entry.data)                    // file data
        }

        // ---- Central directory ----

        let centralDirOffset = UInt32(archive.count)

        for ce in centralEntries {
            archive.slidesAppendUInt32(0x02014b50)       // signature
            archive.slidesAppendUInt16(20)               // version made by
            archive.slidesAppendUInt16(20)               // version needed
            archive.slidesAppendUInt16(0)                 // flags
            archive.slidesAppendUInt16(0)                 // compression method
            archive.slidesAppendUInt16(0)                 // last mod time
            archive.slidesAppendUInt16(0)                 // last mod date
            archive.slidesAppendUInt32(ce.crc32)          // CRC-32
            archive.slidesAppendUInt32(ce.size)           // compressed size
            archive.slidesAppendUInt32(ce.size)           // uncompressed size
            archive.slidesAppendUInt16(UInt16(ce.pathData.count)) // name length
            archive.slidesAppendUInt16(0)                 // extra field length
            archive.slidesAppendUInt16(0)                 // comment length
            archive.slidesAppendUInt16(0)                 // disk number start
            archive.slidesAppendUInt16(0)                 // internal file attributes
            archive.slidesAppendUInt32(0)                 // external file attributes
            archive.slidesAppendUInt32(ce.localHeaderOffset) // relative offset
            archive.append(ce.pathData)                   // file name
        }

        let centralDirSize = UInt32(archive.count) - centralDirOffset

        // ---- End of central directory record ----

        archive.slidesAppendUInt32(0x06054b50)           // signature
        archive.slidesAppendUInt16(0)                     // disk number
        archive.slidesAppendUInt16(0)                     // disk with central dir
        archive.slidesAppendUInt16(UInt16(entries.count)) // entries on this disk
        archive.slidesAppendUInt16(UInt16(entries.count)) // total entries
        archive.slidesAppendUInt32(centralDirSize)        // central dir size
        archive.slidesAppendUInt32(centralDirOffset)      // central dir offset
        archive.slidesAppendUInt16(0)                     // comment length

        return archive
    }
}

// MARK: - Data helpers for little-endian integer writing

private extension Data {
    mutating func slidesAppendUInt16(_ value: UInt16) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }

    mutating func slidesAppendUInt32(_ value: UInt32) {
        var le = value.littleEndian
        Swift.withUnsafeBytes(of: &le) { append(contentsOf: $0) }
    }
}

// MARK: - CRC32

/// Standard CRC-32 implementation using the IEEE 802.3 polynomial.
enum SlidesCRC32: Sendable {

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

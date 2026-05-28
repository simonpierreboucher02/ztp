// SlidesValidator.swift
// ZTPSlides – Structural validation of .pptx files.

import Foundation

// MARK: - SlidesValidator

/// Validates that a `.pptx` file is structurally well-formed by checking
/// required files, XML structure, and internal references.
public struct SlidesValidator: Sendable {

    // MARK: - Result Types

    /// The overall result of validating a `.pptx` file.
    public struct ValidationResult: Codable, Sendable {
        public let valid: Bool
        public let checks: [ValidationCheck]
    }

    /// A single validation check result.
    public struct ValidationCheck: Codable, Sendable {
        public let name: String
        public let passed: Bool
        public let message: String?
    }

    // MARK: - Required paths

    private static let requiredFiles = [
        "[Content_Types].xml",
        "_rels/.rels",
        "ppt/presentation.xml",
    ]

    // MARK: - Public API

    /// Validates a `.pptx` file at the given path.
    ///
    /// Runs a series of structural checks and returns the results.
    ///
    /// - Parameter path: The file system path to the `.pptx` file.
    /// - Returns: A ``ValidationResult`` with individual check outcomes.
    public static func validate(at path: String) throws -> ValidationResult {
        var checks: [ValidationCheck] = []

        // 1. ZIP readable
        let entries: [SlidesZIPReader.Entry]
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            entries = try SlidesZIPReader.readEntries(from: data)
            checks.append(ValidationCheck(
                name: "zip_readable",
                passed: true,
                message: nil
            ))
        } catch {
            checks.append(ValidationCheck(
                name: "zip_readable",
                passed: false,
                message: "Failed to read ZIP archive: \(error)"
            ))
            return ValidationResult(valid: false, checks: checks)
        }

        let entryPaths = Set(entries.map(\.path))
        let entryMap = Dictionary(entries.map { ($0.path, $0.data) }, uniquingKeysWith: { first, _ in first })

        // 2. Required files present
        for requiredPath in requiredFiles {
            let found = entryPaths.contains(requiredPath)
            checks.append(ValidationCheck(
                name: "required_file_\(requiredPath)",
                passed: found,
                message: found ? nil : "Missing required file: \(requiredPath)"
            ))
        }

        // 3. Presentation has slides
        if let presentationData = entryMap["ppt/presentation.xml"],
           let presentationXml = String(data: presentationData, encoding: .utf8)
        {
            let slideRIds = SlidesXMLParser.extractSlideReferences(from: presentationXml)
            let hasSlides = !slideRIds.isEmpty
            checks.append(ValidationCheck(
                name: "presentation_has_slides",
                passed: hasSlides,
                message: hasSlides ? nil : "Presentation contains no slide references"
            ))

            // 4. Each referenced slide file exists
            if let relsData = entryMap["ppt/_rels/presentation.xml.rels"],
               let relsXml = String(data: relsData, encoding: .utf8)
            {
                let relationships = SlidesXMLParser.extractRelationships(from: relsXml)
                let relMap = Dictionary(
                    relationships.map { ($0.id, $0) },
                    uniquingKeysWith: { first, _ in first }
                )

                var allSlidesExist = true
                var missingSlides: [String] = []

                for rId in slideRIds {
                    if let rel = relMap[rId] {
                        let target = rel.target
                        let fullPath: String
                        if target.hasPrefix("/") {
                            fullPath = String(target.dropFirst())
                        } else {
                            fullPath = "ppt/" + target
                        }

                        if !entryPaths.contains(fullPath) {
                            allSlidesExist = false
                            missingSlides.append(fullPath)
                        }
                    } else {
                        allSlidesExist = false
                        missingSlides.append("unresolved:\(rId)")
                    }
                }

                checks.append(ValidationCheck(
                    name: "referenced_slides_exist",
                    passed: allSlidesExist,
                    message: allSlidesExist ? nil : "Missing slide files: \(missingSlides.joined(separator: ", "))"
                ))
            } else {
                checks.append(ValidationCheck(
                    name: "referenced_slides_exist",
                    passed: false,
                    message: "Missing ppt/_rels/presentation.xml.rels to resolve slide references"
                ))
            }

            // 6. XML well-formed (basic check on presentation.xml)
            let wellFormed = basicXMLWellFormedCheck(presentationXml)
            checks.append(ValidationCheck(
                name: "xml_well_formed",
                passed: wellFormed,
                message: wellFormed ? nil : "ppt/presentation.xml appears malformed (unbalanced angle brackets)"
            ))
        } else {
            checks.append(ValidationCheck(
                name: "presentation_has_slides",
                passed: false,
                message: "Cannot read ppt/presentation.xml"
            ))
            checks.append(ValidationCheck(
                name: "referenced_slides_exist",
                passed: false,
                message: "Cannot read ppt/presentation.xml"
            ))
            checks.append(ValidationCheck(
                name: "xml_well_formed",
                passed: false,
                message: "Cannot read ppt/presentation.xml"
            ))
        }

        // 5. Theme file exists
        let hasTheme = entryPaths.contains("ppt/theme/theme1.xml")
        checks.append(ValidationCheck(
            name: "theme_file_exists",
            passed: hasTheme,
            message: hasTheme ? nil : "Missing ppt/theme/theme1.xml"
        ))

        // 7. Referenced images exist in ppt/media/
        let imageCheck = validateReferencedImages(entries: entries, entryPaths: entryPaths, entryMap: entryMap)
        checks.append(imageCheck)

        // 8. Content types valid
        if let ctData = entryMap["[Content_Types].xml"],
           let ctXml = String(data: ctData, encoding: .utf8)
        {
            let hasPresentationContentType =
                ctXml.contains("presentationml.presentation") ||
                ctXml.contains("presentationml.slideshow") ||
                ctXml.contains("application/vnd.openxmlformats-officedocument.presentationml")
            checks.append(ValidationCheck(
                name: "content_types_valid",
                passed: hasPresentationContentType,
                message: hasPresentationContentType
                    ? nil
                    : "[Content_Types].xml does not declare a presentation content type"
            ))
        } else {
            checks.append(ValidationCheck(
                name: "content_types_valid",
                passed: false,
                message: "Cannot read [Content_Types].xml"
            ))
        }

        let allPassed = checks.allSatisfy(\.passed)
        return ValidationResult(valid: allPassed, checks: checks)
    }

    // MARK: - Private Helpers

    /// Validates that images referenced in slides exist in the archive.
    private static func validateReferencedImages(
        entries: [SlidesZIPReader.Entry],
        entryPaths: Set<String>,
        entryMap: [String: Data]
    ) -> ValidationCheck {
        // Find all slide files and their relationship files
        let slideEntries = entries.filter {
            $0.path.hasPrefix("ppt/slides/slide") && $0.path.hasSuffix(".xml") && !$0.path.contains("_rels")
        }

        var allImagesExist = true
        var missingImages: [String] = []

        for slideEntry in slideEntries {
            guard let slideXml = String(data: slideEntry.data, encoding: .utf8) else {
                continue
            }

            let imageCount = SlidesXMLParser.countImages(in: slideXml)
            if imageCount == 0 {
                continue
            }

            // Find the rels file for this slide
            let slideFileName = URL(fileURLWithPath: slideEntry.path).lastPathComponent
            let relsPath = "ppt/slides/_rels/\(slideFileName).rels"

            guard let relsData = entryMap[relsPath],
                  let relsXml = String(data: relsData, encoding: .utf8) else {
                continue
            }

            let relationships = SlidesXMLParser.extractRelationships(from: relsXml)
            let imageRels = relationships.filter { rel in
                rel.type.contains("image") || rel.type.contains("Image")
            }

            for imageRel in imageRels {
                let target = imageRel.target
                let fullPath: String
                if target.hasPrefix("/") {
                    fullPath = String(target.dropFirst())
                } else if target.hasPrefix("../") {
                    // Relative to ppt/slides/, so ../media/image1.png -> ppt/media/image1.png
                    fullPath = "ppt/" + String(target.dropFirst(3))
                } else {
                    fullPath = "ppt/slides/" + target
                }

                if !entryPaths.contains(fullPath) {
                    allImagesExist = false
                    missingImages.append(fullPath)
                }
            }
        }

        return ValidationCheck(
            name: "referenced_images_exist",
            passed: allImagesExist,
            message: allImagesExist ? nil : "Missing image files: \(missingImages.joined(separator: ", "))"
        )
    }

    /// Basic XML well-formedness check: verifies angle brackets are balanced.
    private static func basicXMLWellFormedCheck(_ xml: String) -> Bool {
        var depth = 0

        for char in xml {
            if char == "<" {
                depth += 1
            } else if char == ">" {
                depth -= 1
                if depth < 0 {
                    return false
                }
            }
        }

        return depth == 0
    }
}

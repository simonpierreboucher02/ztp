// DocxValidator.swift
// ZTPDocx – Structural validation of .docx files.

import Foundation

// MARK: - DocxValidator

/// Validates that a `.docx` file is structurally well-formed by checking
/// required files, XML structure, and internal references.
public struct DocxValidator: Sendable {

    // MARK: - Result Types

    /// The overall result of validating a `.docx` file.
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
        "word/document.xml",
    ]

    // MARK: - Public API

    /// Validates a `.docx` file at the given path.
    ///
    /// Runs a series of structural checks and returns the results.
    ///
    /// - Parameter path: The file system path to the `.docx` file.
    /// - Returns: A ``ValidationResult`` with individual check outcomes.
    public static func validate(at path: String) throws -> ValidationResult {
        var checks: [ValidationCheck] = []

        // 1. ZIP readable
        let entries: [DocxZIPReader.Entry]
        do {
            let url = URL(fileURLWithPath: path)
            let data = try Data(contentsOf: url)
            entries = try DocxZIPReader.readEntries(from: data)
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

        // 2. Required files present
        for requiredPath in requiredFiles {
            let found = entryPaths.contains(requiredPath)
            checks.append(ValidationCheck(
                name: "required_file_\(requiredPath)",
                passed: found,
                message: found ? nil : "Missing required file: \(requiredPath)"
            ))
        }

        // 3. word/document.xml contains body element
        if let docEntry = entries.first(where: { $0.path == "word/document.xml" }),
           let docXml = String(data: docEntry.data, encoding: .utf8)
        {
            let hasBody = docXml.contains("<w:body") || docXml.contains("<w:body>")
            checks.append(ValidationCheck(
                name: "document_has_body",
                passed: hasBody,
                message: hasBody ? nil : "word/document.xml does not contain a <w:body> element"
            ))

            // 5. XML well-formed (basic check)
            let wellFormed = basicXMLWellFormedCheck(docXml)
            checks.append(ValidationCheck(
                name: "xml_well_formed",
                passed: wellFormed,
                message: wellFormed ? nil : "word/document.xml appears malformed (unbalanced angle brackets)"
            ))

            // 6. Referenced images exist in word/media/
            let imageRIds = DocxXMLParser.extractImages(from: docXml)
            if !imageRIds.isEmpty {
                if let relsEntry = entries.first(where: { $0.path == "word/_rels/document.xml.rels" }),
                   let relsXml = String(data: relsEntry.data, encoding: .utf8)
                {
                    let relationships = DocxXMLParser.extractRelationships(from: relsXml)
                    let imageTargets = relationships
                        .filter { $0.type.contains("image") || $0.type.contains("Image") }
                        .filter { imageRIds.contains($0.id) }
                        .map(\.target)

                    var allImagesExist = true
                    var missingImages: [String] = []

                    for target in imageTargets {
                        // Targets are relative to the word/ directory
                        let fullPath: String
                        if target.hasPrefix("/") {
                            fullPath = String(target.dropFirst())
                        } else {
                            fullPath = "word/" + target
                        }

                        if !entryPaths.contains(fullPath) {
                            allImagesExist = false
                            missingImages.append(fullPath)
                        }
                    }

                    checks.append(ValidationCheck(
                        name: "referenced_images_exist",
                        passed: allImagesExist,
                        message: allImagesExist ? nil : "Missing image files: \(missingImages.joined(separator: ", "))"
                    ))
                } else {
                    checks.append(ValidationCheck(
                        name: "referenced_images_exist",
                        passed: false,
                        message: "Document references images but word/_rels/document.xml.rels is missing"
                    ))
                }
            } else {
                checks.append(ValidationCheck(
                    name: "referenced_images_exist",
                    passed: true,
                    message: nil
                ))
            }
        } else {
            checks.append(ValidationCheck(
                name: "document_has_body",
                passed: false,
                message: "Cannot read word/document.xml"
            ))
            checks.append(ValidationCheck(
                name: "xml_well_formed",
                passed: false,
                message: "Cannot read word/document.xml"
            ))
            checks.append(ValidationCheck(
                name: "referenced_images_exist",
                passed: false,
                message: "Cannot read word/document.xml"
            ))
        }

        // 4. Relationships file exists
        let hasRels = entryPaths.contains("word/_rels/document.xml.rels")
        checks.append(ValidationCheck(
            name: "relationships_file_exists",
            passed: hasRels,
            message: hasRels ? nil : "Missing word/_rels/document.xml.rels"
        ))

        // 7. Styles file exists
        let hasStyles = entryPaths.contains("word/styles.xml")
        checks.append(ValidationCheck(
            name: "styles_file_exists",
            passed: hasStyles,
            message: hasStyles ? nil : "Missing word/styles.xml"
        ))

        let allPassed = checks.allSatisfy(\.passed)
        return ValidationResult(valid: allPassed, checks: checks)
    }

    // MARK: - Private Helpers

    /// Basic XML well-formedness check: verifies angle brackets are balanced
    /// and there are no obvious structural issues.
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

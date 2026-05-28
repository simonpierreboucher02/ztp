// DocxSpecValidator.swift
// ZTPDocx – Validates a DocumentSpec JSON before document generation.

import Foundation

// MARK: - DocxSpecValidator

/// Validates a ``DocumentSpec`` for correctness before attempting document
/// generation. Catches structural and semantic errors early with clear
/// error codes and hints.
public struct DocxSpecValidator: Sendable {

    // MARK: - Result Types

    /// The overall result of validating a ``DocumentSpec``.
    public struct SpecValidationResult: Codable, Sendable {
        public let valid: Bool
        public let errors: [SpecValidationError]
    }

    /// A single validation error with a machine-readable code and human-readable message.
    public struct SpecValidationError: Codable, Sendable {
        public let code: String
        public let message: String
        public let path: String?
        public let hint: String?
    }

    // MARK: - Public API

    /// Validates a ``DocumentSpec`` instance.
    ///
    /// - Parameter spec: The document specification to validate.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(spec: DocumentSpec) -> SpecValidationResult {
        var errors: [SpecValidationError] = []

        // 1. Version check
        if spec.version != "ztp-docx/0.1" {
            errors.append(SpecValidationError(
                code: "INVALID_VERSION",
                message: "Version must be \"ztp-docx/0.1\", got \"\(spec.version)\"",
                path: "version",
                hint: "Set version to \"ztp-docx/0.1\""
            ))
        }

        // 2. At least one section
        if spec.sections.isEmpty {
            errors.append(SpecValidationError(
                code: "NO_SECTIONS",
                message: "Document must have at least one section",
                path: "sections",
                hint: "Add at least one section with elements"
            ))
        }

        // Collect all referenced styles
        var referencedStyles: [(name: String, path: String)] = []

        // 3. Validate each section
        for (sectionIndex, section) in spec.sections.enumerated() {
            let sectionPath = "sections[\(sectionIndex)]"

            // Sections must have at least one element
            if section.elements.isEmpty {
                errors.append(SpecValidationError(
                    code: "EMPTY_SECTION",
                    message: "Section \(sectionIndex) has no elements",
                    path: "\(sectionPath).elements",
                    hint: "Add at least one element to the section"
                ))
            }

            // Validate each element
            for (elementIndex, element) in section.elements.enumerated() {
                let elementPath = "\(sectionPath).elements[\(elementIndex)]"

                switch element {
                case let .heading(level, text, style):
                    // Heading level must be 1-9
                    if level < 1 || level > 9 {
                        errors.append(SpecValidationError(
                            code: "INVALID_HEADING_LEVEL",
                            message: "Heading level must be 1-9, got \(level)",
                            path: "\(elementPath).level",
                            hint: "Use a heading level between 1 and 9"
                        ))
                    }

                    // Heading text must not be empty
                    if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errors.append(SpecValidationError(
                            code: "EMPTY_HEADING_TEXT",
                            message: "Heading text must not be empty",
                            path: "\(elementPath).text",
                            hint: "Provide non-empty text for the heading"
                        ))
                    }

                    if let style = style {
                        referencedStyles.append((name: style, path: "\(elementPath).style"))
                    }

                case let .paragraph(_, _, style, _):
                    if let style = style {
                        referencedStyles.append((name: style, path: "\(elementPath).style"))
                    }

                case let .table(headers, rows, style, _):
                    // Check table has some content
                    if rows.isEmpty && (headers == nil || headers!.isEmpty) {
                        errors.append(SpecValidationError(
                            code: "EMPTY_TABLE",
                            message: "Table has no rows or headers",
                            path: elementPath,
                            hint: "Add at least one row or header to the table"
                        ))
                    }

                    // Check rows have consistent column count
                    if !rows.isEmpty {
                        let expectedColumns: Int
                        if let headers = headers, !headers.isEmpty {
                            expectedColumns = headers.count
                        } else {
                            expectedColumns = rows[0].count
                        }

                        for (rowIndex, row) in rows.enumerated() {
                            if row.count != expectedColumns {
                                errors.append(SpecValidationError(
                                    code: "INCONSISTENT_TABLE_COLUMNS",
                                    message: "Row \(rowIndex) has \(row.count) columns, expected \(expectedColumns)",
                                    path: "\(elementPath).rows[\(rowIndex)]",
                                    hint: "Ensure all rows have the same number of columns as the header or first row"
                                ))
                            }
                        }
                    }

                    if let style = style {
                        referencedStyles.append((name: style, path: "\(elementPath).style"))
                    }

                case let .image(path, _, _, _):
                    // Image path must not be empty
                    if path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        errors.append(SpecValidationError(
                            code: "EMPTY_IMAGE_PATH",
                            message: "Image path must not be empty",
                            path: "\(elementPath).path",
                            hint: "Provide a valid file path for the image"
                        ))
                    }

                case .bulletList, .numberedList, .pageBreak, .horizontalRule:
                    break
                }
            }
        }

        // 4. Check referenced styles exist in the styles dictionary
        if let styles = spec.styles, !styles.isEmpty {
            let definedStyleNames = Set(styles.keys)
            for (styleName, stylePath) in referencedStyles {
                if !definedStyleNames.contains(styleName) {
                    errors.append(SpecValidationError(
                        code: "UNDEFINED_STYLE",
                        message: "Style \"\(styleName)\" is referenced but not defined in the styles dictionary",
                        path: stylePath,
                        hint: "Add \"\(styleName)\" to the styles dictionary or remove the reference"
                    ))
                }
            }
        }

        return SpecValidationResult(valid: errors.isEmpty, errors: errors)
    }

    /// Validates a ``DocumentSpec`` from raw JSON data.
    ///
    /// First attempts to decode the JSON, then validates the decoded spec.
    ///
    /// - Parameter jsonData: The raw JSON bytes.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(jsonData: Data) -> SpecValidationResult {
        let decoder = JSONDecoder()

        do {
            let spec = try decoder.decode(DocumentSpec.self, from: jsonData)
            return validate(spec: spec)
        } catch {
            return SpecValidationResult(
                valid: false,
                errors: [
                    SpecValidationError(
                        code: "JSON_DECODE_ERROR",
                        message: "Failed to decode JSON: \(error.localizedDescription)",
                        path: nil,
                        hint: "Ensure the JSON conforms to the DocumentSpec schema"
                    ),
                ]
            )
        }
    }
}

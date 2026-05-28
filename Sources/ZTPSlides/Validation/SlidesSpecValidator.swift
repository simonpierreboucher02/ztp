// SlidesSpecValidator.swift
// ZTPSlides – Validates a PresentationSpec JSON before presentation generation.

import Foundation

// MARK: - SlidesSpecValidator

/// Validates a ``PresentationSpec`` for correctness before attempting
/// presentation generation. Catches structural and semantic errors early
/// with clear error codes and hints.
public struct SlidesSpecValidator: Sendable {

    // MARK: - Result Types

    /// The overall result of validating a ``PresentationSpec``.
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

    // MARK: - Valid layout names

    private static let validLayouts: Set<String> = [
        "title", "title-content", "two-column", "image-right",
        "image-left", "table", "section-divider", "quote", "blank",
    ]

    // MARK: - Valid sizes

    private static let validSizes: Set<String> = [
        "16:9", "4:3",
    ]

    // MARK: - Public API

    /// Validates a ``PresentationSpec`` instance.
    ///
    /// - Parameter spec: The presentation specification to validate.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(spec: PresentationSpec) -> SpecValidationResult {
        var errors: [SpecValidationError] = []

        // 1. Version check
        if spec.version != "ztp-slides/0.1" {
            errors.append(SpecValidationError(
                code: "INVALID_VERSION",
                message: "Version must be \"ztp-slides/0.1\", got \"\(spec.version)\"",
                path: "version",
                hint: "Set version to \"ztp-slides/0.1\""
            ))
        }

        // 2. At least one slide
        if spec.slides.isEmpty {
            errors.append(SpecValidationError(
                code: "NO_SLIDES",
                message: "Presentation must have at least one slide",
                path: "slides",
                hint: "Add at least one slide with content"
            ))
        }

        // 3. Validate size if specified
        if let size = spec.presentation?.size {
            if !validSizes.contains(size) {
                errors.append(SpecValidationError(
                    code: "INVALID_SIZE",
                    message: "Size must be \"16:9\" or \"4:3\", got \"\(size)\"",
                    path: "presentation.size",
                    hint: "Use \"16:9\" for widescreen or \"4:3\" for standard"
                ))
            }
        }

        // 4. Validate each slide
        for (slideIndex, slide) in spec.slides.enumerated() {
            let slidePath = "slides[\(slideIndex)]"

            // Validate layout name
            if let layout = slide.layout {
                if !validLayouts.contains(layout) {
                    errors.append(SpecValidationError(
                        code: "INVALID_LAYOUT",
                        message: "Invalid layout \"\(layout)\" on slide \(slideIndex)",
                        path: "\(slidePath).layout",
                        hint: "Valid layouts: \(validLayouts.sorted().joined(separator: ", "))"
                    ))
                }
            }

            // Validate content elements
            if let content = slide.content {
                for (elementIndex, element) in content.enumerated() {
                    let elementPath = "\(slidePath).content[\(elementIndex)]"
                    validateContentSpec(element, path: elementPath, errors: &errors)
                }
            }

            // Validate shorthand table
            if let table = slide.table {
                let tablePath = "\(slidePath).table"
                if table.rows.isEmpty {
                    errors.append(SpecValidationError(
                        code: "EMPTY_TABLE_ROWS",
                        message: "Table rows must not be empty on slide \(slideIndex)",
                        path: "\(tablePath).rows",
                        hint: "Add at least one row to the table"
                    ))
                }
            }
        }

        return SpecValidationResult(valid: errors.isEmpty, errors: errors)
    }

    /// Validates a ``PresentationSpec`` from raw JSON data.
    ///
    /// First attempts to decode the JSON, then validates the decoded spec.
    ///
    /// - Parameter jsonData: The raw JSON bytes.
    /// - Returns: A ``SpecValidationResult`` with any errors found.
    public static func validate(jsonData: Data) -> SpecValidationResult {
        let decoder = JSONDecoder()

        do {
            let spec = try decoder.decode(PresentationSpec.self, from: jsonData)
            return validate(spec: spec)
        } catch {
            return SpecValidationResult(
                valid: false,
                errors: [
                    SpecValidationError(
                        code: "JSON_DECODE_ERROR",
                        message: "Failed to decode JSON: \(error.localizedDescription)",
                        path: nil,
                        hint: "Ensure the JSON conforms to the PresentationSpec schema"
                    ),
                ]
            )
        }
    }

    // MARK: - Private Helpers

    /// Validates a single content element spec.
    private static func validateContentSpec(
        _ spec: ContentSpec,
        path: String,
        errors: inout [SpecValidationError]
    ) {
        switch spec {
        case .image(let imagePath, _, _, _, _):
            // Image path must not be empty
            if imagePath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(SpecValidationError(
                    code: "EMPTY_IMAGE_PATH",
                    message: "Image path must not be empty",
                    path: "\(path).path",
                    hint: "Provide a valid file path for the image"
                ))
            }

        case .table(let tableSpec):
            // Table rows must not be empty
            if tableSpec.rows.isEmpty {
                errors.append(SpecValidationError(
                    code: "EMPTY_TABLE_ROWS",
                    message: "Table rows must not be empty",
                    path: "\(path).rows",
                    hint: "Add at least one row to the table"
                ))
            }

            // Check column consistency
            if !tableSpec.rows.isEmpty {
                let expectedColumns: Int
                if let headers = tableSpec.headers, !headers.isEmpty {
                    expectedColumns = headers.count
                } else {
                    expectedColumns = tableSpec.rows[0].count
                }

                for (rowIndex, row) in tableSpec.rows.enumerated() {
                    if row.count != expectedColumns {
                        errors.append(SpecValidationError(
                            code: "INCONSISTENT_TABLE_COLUMNS",
                            message: "Row \(rowIndex) has \(row.count) columns, expected \(expectedColumns)",
                            path: "\(path).rows[\(rowIndex)]",
                            hint: "Ensure all rows have the same number of columns"
                        ))
                    }
                }
            }

        case .kpi(let label, let value, _):
            // KPI label must not be empty
            if label.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(SpecValidationError(
                    code: "EMPTY_KPI_LABEL",
                    message: "KPI label must not be empty",
                    path: "\(path).label",
                    hint: "Provide a non-empty label for the KPI"
                ))
            }
            // KPI value must not be empty
            if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                errors.append(SpecValidationError(
                    code: "EMPTY_KPI_VALUE",
                    message: "KPI value must not be empty",
                    path: "\(path).value",
                    hint: "Provide a non-empty value for the KPI"
                ))
            }

        case .bullets, .numberedList, .paragraph, .shape, .spacer:
            break
        }
    }
}

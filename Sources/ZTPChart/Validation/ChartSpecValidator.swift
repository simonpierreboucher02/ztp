import Foundation

// MARK: - Chart Spec Validator

public struct ChartSpecValidator: Sendable {

    // MARK: - Result Types

    public struct SpecValidationResult: Codable, Sendable {
        public let valid: Bool
        public let errors: [SpecValidationError]

        public init(valid: Bool, errors: [SpecValidationError]) {
            self.valid = valid
            self.errors = errors
        }
    }

    public struct SpecValidationError: Codable, Sendable {
        public let code: String
        public let message: String
        public let path: String?
        public let hint: String?

        public init(code: String, message: String, path: String? = nil, hint: String? = nil) {
            self.code = code
            self.message = message
            self.path = path
            self.hint = hint
        }
    }

    // MARK: - Known Values

    private static let supportedVersion = "ztp-chart/0.1"

    private static let knownThemeNames: Set<String> = {
        Set(ChartTheme.allThemes.map { $0.name.lowercased() })
    }()

    private static let validFormats: Set<String> = ["png", "svg", "pdf"]

    // MARK: - Validate from ChartSpec

    public static func validate(spec: ChartSpec) -> SpecValidationResult {
        var errors: [SpecValidationError] = []

        // 1. Version check
        if spec.version != supportedVersion {
            errors.append(SpecValidationError(
                code: "INVALID_VERSION",
                message: "Unsupported version '\(spec.version)'.",
                path: "version",
                hint: "Expected '\(supportedVersion)'."
            ))
        }

        // 2. Chart type is valid (already enforced by the enum during decoding,
        //    but the raw value is verified implicitly). No extra check needed here
        //    because ChartSpec.chart.type is ChartType (enum).

        // 3. Dimensions
        let width = spec.chart.width
        let height = spec.chart.height

        if width <= 0 {
            errors.append(SpecValidationError(
                code: "INVALID_WIDTH",
                message: "Width must be greater than 0, got \(width).",
                path: "chart.width",
                hint: "Provide a positive width (100-10000 recommended)."
            ))
        } else if width < 100 || width > 10000 {
            errors.append(SpecValidationError(
                code: "UNREASONABLE_WIDTH",
                message: "Width \(Int(width)) is outside the recommended range 100-10000.",
                path: "chart.width",
                hint: "Consider using a width between 100 and 10000."
            ))
        }

        if height <= 0 {
            errors.append(SpecValidationError(
                code: "INVALID_HEIGHT",
                message: "Height must be greater than 0, got \(height).",
                path: "chart.height",
                hint: "Provide a positive height (100-10000 recommended)."
            ))
        } else if height < 100 || height > 10000 {
            errors.append(SpecValidationError(
                code: "UNREASONABLE_HEIGHT",
                message: "Height \(Int(height)) is outside the recommended range 100-10000.",
                path: "chart.height",
                hint: "Consider using a height between 100 and 10000."
            ))
        }

        // 4. Data presence
        let hasInlineValues = spec.data.values != nil && !(spec.data.values!.isEmpty)
        let hasSource = spec.data.source != nil && !(spec.data.source!.isEmpty)

        if !hasInlineValues && !hasSource {
            errors.append(SpecValidationError(
                code: "MISSING_DATA",
                message: "No data provided. Either 'values' array or 'source' path is required.",
                path: "data",
                hint: "Add inline data via 'values' or reference a CSV file via 'source'."
            ))
        }

        // 5. Chart-type-specific validation
        switch spec.chart.type {
        case .line, .bar, .scatter, .area:
            // Series array should be non-empty
            if spec.series == nil || spec.series!.isEmpty {
                errors.append(SpecValidationError(
                    code: "MISSING_SERIES",
                    message: "Series array is required for \(spec.chart.type.rawValue) charts.",
                    path: "series",
                    hint: "Add at least one series with a 'field' key."
                ))
            }
            // X field should be specified
            if spec.x?.field == nil || (spec.x?.field?.isEmpty ?? true) {
                errors.append(SpecValidationError(
                    code: "MISSING_X_FIELD",
                    message: "X-axis field is required for \(spec.chart.type.rawValue) charts.",
                    path: "x.field",
                    hint: "Set x.field to the column name used for the X axis."
                ))
            }

        case .pie:
            if spec.labelField == nil || (spec.labelField?.isEmpty ?? true) {
                errors.append(SpecValidationError(
                    code: "MISSING_LABEL_FIELD",
                    message: "'label_field' is required for pie charts.",
                    path: "label_field",
                    hint: "Set 'label_field' to the column containing category labels."
                ))
            }
            if spec.valueField == nil || (spec.valueField?.isEmpty ?? true) {
                errors.append(SpecValidationError(
                    code: "MISSING_VALUE_FIELD",
                    message: "'value_field' is required for pie charts.",
                    path: "value_field",
                    hint: "Set 'value_field' to the column containing numeric values."
                ))
            }

        case .candlestick:
            if let ohlc = spec.ohlc {
                if ohlc.date.isEmpty {
                    errors.append(SpecValidationError(
                        code: "MISSING_OHLC_DATE",
                        message: "OHLC 'date' field must be non-empty.",
                        path: "ohlc.date",
                        hint: nil
                    ))
                }
                if ohlc.open.isEmpty {
                    errors.append(SpecValidationError(
                        code: "MISSING_OHLC_OPEN",
                        message: "OHLC 'open' field must be non-empty.",
                        path: "ohlc.open",
                        hint: nil
                    ))
                }
                if ohlc.high.isEmpty {
                    errors.append(SpecValidationError(
                        code: "MISSING_OHLC_HIGH",
                        message: "OHLC 'high' field must be non-empty.",
                        path: "ohlc.high",
                        hint: nil
                    ))
                }
                if ohlc.low.isEmpty {
                    errors.append(SpecValidationError(
                        code: "MISSING_OHLC_LOW",
                        message: "OHLC 'low' field must be non-empty.",
                        path: "ohlc.low",
                        hint: nil
                    ))
                }
                if ohlc.close.isEmpty {
                    errors.append(SpecValidationError(
                        code: "MISSING_OHLC_CLOSE",
                        message: "OHLC 'close' field must be non-empty.",
                        path: "ohlc.close",
                        hint: nil
                    ))
                }
            } else {
                errors.append(SpecValidationError(
                    code: "MISSING_OHLC",
                    message: "OHLC specification is required for candlestick charts.",
                    path: "ohlc",
                    hint: "Provide ohlc with date, open, high, low, close field mappings."
                ))
            }

        case .heatmap:
            // Just needs data present, already checked above
            break
        }

        // 6. Theme validation (warning, not failure)
        if let themeName = spec.chart.theme {
            let normalized = themeName.lowercased()
                .replacingOccurrences(of: "-", with: "")
                .replacingOccurrences(of: "_", with: "")
                .replacingOccurrences(of: " ", with: "")
            let knownNormalized = ChartTheme.allThemes.map { theme in
                theme.name.lowercased()
                    .replacingOccurrences(of: "-", with: "")
                    .replacingOccurrences(of: "_", with: "")
                    .replacingOccurrences(of: " ", with: "")
            }
            if !knownNormalized.contains(normalized) {
                // Warning -- does not cause valid=false
                errors.append(SpecValidationError(
                    code: "UNKNOWN_THEME",
                    message: "Theme '\(themeName)' is not a known built-in theme. Default theme will be used.",
                    path: "chart.theme",
                    hint: "Available themes: \(ChartTheme.allThemes.map { $0.name }.joined(separator: ", "))"
                ))
            }
        }

        // 7. Series fields are non-empty strings
        if let seriesList = spec.series {
            for (i, s) in seriesList.enumerated() {
                if s.field.trimmingCharacters(in: .whitespaces).isEmpty {
                    errors.append(SpecValidationError(
                        code: "EMPTY_SERIES_FIELD",
                        message: "Series at index \(i) has an empty 'field' value.",
                        path: "series[\(i)].field",
                        hint: "Each series must reference a valid data column name."
                    ))
                }
            }
        }

        // Determine validity: ignore warnings (UNKNOWN_THEME, UNREASONABLE_*)
        let warningCodes: Set<String> = ["UNKNOWN_THEME", "UNREASONABLE_WIDTH", "UNREASONABLE_HEIGHT"]
        let hasHardErrors = errors.contains { !warningCodes.contains($0.code) }

        return SpecValidationResult(valid: !hasHardErrors, errors: errors)
    }

    // MARK: - Validate from JSON Data

    public static func validate(jsonData: Data) -> SpecValidationResult {
        let spec: ChartSpec
        do {
            spec = try ChartSpec.from(json: jsonData)
        } catch let decodingError as DecodingError {
            let message: String
            switch decodingError {
            case .keyNotFound(let key, _):
                message = "Missing required key '\(key.stringValue)'."
            case .typeMismatch(let type, let context):
                message = "Type mismatch for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)."
            case .valueNotFound(let type, let context):
                message = "Null value for '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': expected \(type)."
            case .dataCorrupted(let context):
                message = "Corrupted data at '\(context.codingPath.map { $0.stringValue }.joined(separator: "."))': \(context.debugDescription)"
            @unknown default:
                message = "Decoding error: \(decodingError.localizedDescription)"
            }
            return SpecValidationResult(valid: false, errors: [
                SpecValidationError(
                    code: "DECODE_ERROR",
                    message: message,
                    path: nil,
                    hint: "Ensure the JSON conforms to the ztp-chart spec schema."
                )
            ])
        } catch {
            return SpecValidationResult(valid: false, errors: [
                SpecValidationError(
                    code: "PARSE_ERROR",
                    message: "Failed to parse JSON: \(error.localizedDescription)",
                    path: nil,
                    hint: "Ensure the input is valid JSON."
                )
            ])
        }

        return validate(spec: spec)
    }
}

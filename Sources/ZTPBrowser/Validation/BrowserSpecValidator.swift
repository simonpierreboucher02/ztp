import Foundation

public struct BrowserSpecValidator: Sendable {

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

    // MARK: - Validate from decoded spec

    public static func validate(spec: BrowserSpec) -> SpecValidationResult {
        var errors: [SpecValidationError] = []

        // Validate version
        if !spec.version.hasPrefix("ztp-browser/") {
            errors.append(SpecValidationError(
                code: "UNSUPPORTED_VERSION",
                message: "Version '\(spec.version)' is not supported.",
                path: "version",
                hint: "Use a version starting with 'ztp-browser/', e.g. 'ztp-browser/0.1'."
            ))
        }

        // Validate action
        let validActions = Set(["screenshot", "pdf", "html", "text", "links", "metadata", "open", "inspect"])
        let action = spec.task.action.lowercased()
        if !validActions.contains(action) {
            errors.append(SpecValidationError(
                code: "INVALID_ACTION",
                message: "Action '\(spec.task.action)' is not a recognized browser action.",
                path: "task.action",
                hint: "Valid actions: \(validActions.sorted().joined(separator: ", "))."
            ))
        }

        // Validate URL
        let urlResult = URLValidator.validate(urlString: spec.task.url)
        if !urlResult.valid {
            for urlError in urlResult.errors where urlError.code != "LOCALHOST_WARNING" {
                errors.append(SpecValidationError(
                    code: urlError.code,
                    message: urlError.message,
                    path: "task.url",
                    hint: urlError.hint
                ))
            }
        }

        // Validate wait strategy if provided
        if let strategy = spec.task.wait?.strategy {
            let validStrategies = Set(["dom-ready", "network-idle", "timeout"])
            if !validStrategies.contains(strategy) {
                errors.append(SpecValidationError(
                    code: "INVALID_WAIT_STRATEGY",
                    message: "Wait strategy '\(strategy)' is not recognized.",
                    path: "task.wait.strategy",
                    hint: "Valid strategies: dom-ready, network-idle, timeout."
                ))
            }
        }

        // Validate timeout if provided
        if let timeoutMs = spec.task.wait?.timeoutMs, timeoutMs <= 0 {
            errors.append(SpecValidationError(
                code: "INVALID_TIMEOUT",
                message: "Timeout must be a positive integer, got \(timeoutMs).",
                path: "task.wait.timeout_ms",
                hint: "Provide a timeout in milliseconds, e.g. 5000."
            ))
        }

        // Validate viewport dimensions if provided
        if let vp = spec.task.viewport {
            if let w = vp.width, w <= 0 {
                errors.append(SpecValidationError(
                    code: "INVALID_VIEWPORT_WIDTH",
                    message: "Viewport width must be positive, got \(w).",
                    path: "task.viewport.width",
                    hint: nil
                ))
            }
            if let h = vp.height, h <= 0 {
                errors.append(SpecValidationError(
                    code: "INVALID_VIEWPORT_HEIGHT",
                    message: "Viewport height must be positive, got \(h).",
                    path: "task.viewport.height",
                    hint: nil
                ))
            }
            if let s = vp.scale, s <= 0 {
                errors.append(SpecValidationError(
                    code: "INVALID_VIEWPORT_SCALE",
                    message: "Viewport scale must be positive, got \(s).",
                    path: "task.viewport.scale",
                    hint: nil
                ))
            }
        }

        return SpecValidationResult(valid: errors.isEmpty, errors: errors)
    }

    // MARK: - Validate from raw JSON data

    public static func validate(jsonData: Data) -> SpecValidationResult {
        let decoder = JSONDecoder()
        do {
            let spec = try decoder.decode(BrowserSpec.self, from: jsonData)
            return validate(spec: spec)
        } catch {
            return SpecValidationResult(valid: false, errors: [
                SpecValidationError(
                    code: "INVALID_JSON",
                    message: "Failed to decode BrowserSpec: \(error.localizedDescription)",
                    path: nil,
                    hint: "Ensure the JSON conforms to the BrowserSpec schema."
                )
            ])
        }
    }
}

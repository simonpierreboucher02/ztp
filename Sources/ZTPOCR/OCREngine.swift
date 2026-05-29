import Foundation
import Vision
import AppKit
import CoreGraphics

// MARK: - Models

/// A single recognized line of text with its confidence and normalized
/// bounding box (origin bottom-left, 0...1 in both axes, Vision convention).
public struct OCRLine: Sendable {
    public let text: String
    public let confidence: Double
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
}

/// The result of an OCR pass over one image (or one rasterized PDF page).
public struct OCRResult: Sendable {
    public let text: String
    public let lines: [OCRLine]
    public let language: String?
    public let pageIndex: Int?

    public init(text: String, lines: [OCRLine], language: String?, pageIndex: Int? = nil) {
        self.text = text
        self.lines = lines
        self.language = language
        self.pageIndex = pageIndex
    }
}

// MARK: - Errors

public enum OCRError: Error, Sendable, CustomStringConvertible {
    case cannotLoadImage(String)
    case cannotLoadPDF(String)
    case captureFailed(String)
    case recognitionFailed(String)

    public var description: String {
        switch self {
        case .cannotLoadImage(let p): return "Cannot load image at \(p)"
        case .cannotLoadPDF(let p): return "Cannot load PDF at \(p)"
        case .captureFailed(let m): return "Screen capture failed: \(m)"
        case .recognitionFailed(let m): return "Text recognition failed: \(m)"
        }
    }
}

// MARK: - OCREngine

/// Local, on-device OCR using the Vision framework. No network, no cloud.
public enum OCREngine {

    /// Run text recognition over a single `CGImage`.
    public static func recognize(
        cgImage: CGImage,
        languages: [String] = [],
        fast: Bool = false,
        minConfidence: Double = 0.0
    ) throws -> OCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = fast ? .fast : .accurate
        request.usesLanguageCorrection = !fast
        if !languages.isEmpty {
            request.recognitionLanguages = languages
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
        } catch {
            throw OCRError.recognitionFailed(error.localizedDescription)
        }

        let observations = request.results ?? []
        var lines: [OCRLine] = []
        var texts: [String] = []
        for obs in observations {
            guard let candidate = obs.topCandidates(1).first else { continue }
            let conf = Double(candidate.confidence)
            if conf < minConfidence { continue }
            texts.append(candidate.string)
            let box = obs.boundingBox
            lines.append(OCRLine(
                text: candidate.string,
                confidence: conf,
                x: Double(box.origin.x),
                y: Double(box.origin.y),
                width: Double(box.size.width),
                height: Double(box.size.height)
            ))
        }
        return OCRResult(
            text: texts.joined(separator: "\n"),
            lines: lines,
            language: languages.first
        )
    }

    /// Load an image file (PNG/JPEG/TIFF/HEIC/…) into a `CGImage`.
    public static func loadCGImage(path: String) throws -> CGImage {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw OCRError.cannotLoadImage(expanded)
        }
        guard let nsImage = NSImage(contentsOfFile: expanded) else {
            throw OCRError.cannotLoadImage(expanded)
        }
        var rect = CGRect(origin: .zero, size: nsImage.size)
        guard let cg = nsImage.cgImage(forProposedRect: &rect, context: nil, hints: nil) else {
            throw OCRError.cannotLoadImage(expanded)
        }
        return cg
    }

    /// Recognize text in an image file.
    public static func recognizeImage(
        path: String,
        languages: [String] = [],
        fast: Bool = false,
        minConfidence: Double = 0.0
    ) throws -> OCRResult {
        let cg = try loadCGImage(path: path)
        return try recognize(cgImage: cg, languages: languages, fast: fast, minConfidence: minConfidence)
    }

    /// The recognition languages supported on this machine.
    public static func supportedLanguages(fast: Bool = false) -> [String] {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = fast ? .fast : .accurate
        return (try? request.supportedRecognitionLanguages()) ?? []
    }

    /// Capture the full screen to a temporary PNG and OCR it. Requires Screen
    /// Recording permission. The temp file is removed before returning.
    public static func recognizeScreen(
        languages: [String] = [],
        fast: Bool = false
    ) throws -> OCRResult {
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("ztp-ocr-\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tmp) }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", tmp.path]   // -x = no sound
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw OCRError.captureFailed(error.localizedDescription)
        }
        guard process.terminationStatus == 0,
              FileManager.default.fileExists(atPath: tmp.path) else {
            throw OCRError.captureFailed("screencapture exited \(process.terminationStatus)")
        }
        return try recognizeImage(path: tmp.path, languages: languages, fast: fast)
    }
}

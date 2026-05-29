import Foundation
import PDFKit
import CoreGraphics

/// Rasterizes PDF pages into `CGImage`s so they can be fed to the OCR engine.
public enum PDFRasterizer {

    /// Render selected PDF pages to bitmaps at the given DPI.
    ///
    /// - Parameters:
    ///   - path: PDF file path (tilde-expanded).
    ///   - pageIndices: 0-based page indices to render; `nil` renders all pages.
    ///   - dpi: Target resolution. 200 is a good OCR/quality trade-off.
    /// - Returns: An array of `(pageIndex, image)` in page order.
    public static func pageImages(
        path: String,
        pageIndices: [Int]? = nil,
        dpi: Double = 200
    ) throws -> [(index: Int, image: CGImage)] {
        let expanded = (path as NSString).expandingTildeInPath
        guard FileManager.default.fileExists(atPath: expanded) else {
            throw OCRError.cannotLoadPDF(expanded)
        }
        guard let doc = PDFDocument(url: URL(fileURLWithPath: expanded)) else {
            throw OCRError.cannotLoadPDF(expanded)
        }

        let total = doc.pageCount
        let indices = (pageIndices ?? Array(0..<total)).filter { $0 >= 0 && $0 < total }
        let scale = max(0.5, dpi / 72.0)

        var out: [(index: Int, image: CGImage)] = []
        for i in indices {
            guard let page = doc.page(at: i) else { continue }
            let bounds = page.bounds(for: .mediaBox)
            let width = Int((bounds.width * scale).rounded())
            let height = Int((bounds.height * scale).rounded())
            guard width > 0, height > 0 else { continue }

            guard let ctx = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { continue }

            // White background (PDFs are often transparent).
            ctx.setFillColor(CGColor(red: 1, green: 1, blue: 1, alpha: 1))
            ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
            ctx.scaleBy(x: scale, y: scale)
            ctx.translateBy(x: -bounds.origin.x, y: -bounds.origin.y)
            page.draw(with: .mediaBox, to: ctx)

            if let image = ctx.makeImage() {
                out.append((index: i, image: image))
            }
        }
        return out
    }

    /// Parse a page range string like `"1-3"`, `"1,2,5"`, or `"2-4,7"` into
    /// 0-based indices. Returns `nil` for an empty/whitespace string (= all).
    public static func parsePageRange(_ raw: String?) -> [Int]? {
        guard let raw, !raw.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        var indices: [Int] = []
        for token in raw.split(separator: ",") {
            let part = token.trimmingCharacters(in: .whitespaces)
            if part.contains("-") {
                let bounds = part.split(separator: "-", maxSplits: 1)
                if bounds.count == 2,
                   let lo = Int(bounds[0].trimmingCharacters(in: .whitespaces)),
                   let hi = Int(bounds[1].trimmingCharacters(in: .whitespaces)),
                   lo <= hi {
                    for p in lo...hi { indices.append(p - 1) }
                }
            } else if let p = Int(part) {
                indices.append(p - 1)
            }
        }
        return indices.isEmpty ? nil : Array(Set(indices)).sorted()
    }
}

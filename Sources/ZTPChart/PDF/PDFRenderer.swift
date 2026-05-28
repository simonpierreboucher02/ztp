@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import Foundation

public struct PDFRenderer: Sendable {

    /// Renders drawing commands to PDF data.
    ///
    /// - Parameters:
    ///   - commands: The drawing commands to render.
    ///   - width: PDF page width in points.
    ///   - height: PDF page height in points.
    /// - Returns: PDF data, or nil if rendering fails.
    public static func render(commands: [DrawingCommand], width: Int, height: Int) -> Data? {
        let data = NSMutableData()

        guard let consumer = CGDataConsumer(data: data as CFMutableData) else { return nil }

        var mediaBox = CGRect(x: 0, y: 0, width: width, height: height)

        guard let context = CGContext(consumer: consumer, mediaBox: &mediaBox, nil) else { return nil }

        // Begin PDF page
        context.beginPDFPage(nil)

        // Flip coordinate system: PDF/CoreGraphics is bottom-up, we want top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Execute drawing commands
        CGRenderer.execute(
            commands: commands,
            in: context,
            width: Double(width),
            height: Double(height)
        )

        // End page and close PDF
        context.endPDFPage()
        context.closePDF()

        return data as Data
    }
}

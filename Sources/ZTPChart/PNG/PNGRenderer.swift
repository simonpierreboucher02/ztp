@preconcurrency import CoreGraphics
@preconcurrency import CoreText
import ImageIO
import Foundation

public struct PNGRenderer: Sendable {

    /// Renders drawing commands to PNG image data.
    ///
    /// - Parameters:
    ///   - commands: The drawing commands to render.
    ///   - width: Image width in points.
    ///   - height: Image height in points.
    ///   - scale: Scale factor (default 2 for Retina).
    /// - Returns: PNG data, or nil if rendering fails.
    public static func render(commands: [DrawingCommand], width: Int, height: Int, scale: Int = 2) -> Data? {
        let pixelWidth = width * scale
        let pixelHeight = height * scale
        let bitsPerComponent = 8
        let bytesPerRow = pixelWidth * 4

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else { return nil }

        guard let context = CGContext(
            data: nil,
            width: pixelWidth,
            height: pixelHeight,
            bitsPerComponent: bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Scale for Retina
        context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))

        // Flip coordinate system: CoreGraphics is bottom-up, we want top-left origin
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: 1, y: -1)

        // Execute drawing commands
        CGRenderer.execute(
            commands: commands,
            in: context,
            width: Double(width),
            height: Double(height)
        )

        // Extract CGImage
        guard let cgImage = context.makeImage() else { return nil }

        // Write to PNG data
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data as CFMutableData,
            "public.png" as CFString,
            1,
            nil
        ) else { return nil }

        CGImageDestinationAddImage(destination, cgImage, nil)
        guard CGImageDestinationFinalize(destination) else { return nil }

        return data as Data
    }
}

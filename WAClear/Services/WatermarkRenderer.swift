import Foundation
import CoreImage
import CoreVideo
import UIKit

/// Renders a semi-transparent text watermark onto video frames via CoreImage compositing.
final class WatermarkRenderer {
    private let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])
    private var watermarkImage: CIImage?

    /// Call once before processing begins so the watermark is pre-rendered at the correct size.
    func prepare(targetWidth: Int, targetHeight: Int) {
        watermarkImage = buildWatermark(width: targetWidth, height: targetHeight)
    }

    // MARK: - Frame Processing

    /// Composites the watermark on top of a CIImage and returns the result.
    func applyWatermarkOnCIImage(_ background: CIImage) -> CIImage {
        guard let watermark = watermarkImage else { return background }
        guard let filter = CIFilter(name: "CISourceOverCompositing") else { return background }
        filter.setValue(watermark, forKey: kCIInputImageKey)
        filter.setValue(background, forKey: kCIInputBackgroundImageKey)
        return filter.outputImage ?? background
    }

    /// Composites the watermark onto the given pixel buffer in-place.
    /// - Returns: The same pixel buffer with the watermark applied.
    func applyWatermark(to pixelBuffer: CVPixelBuffer) -> CVPixelBuffer {
        guard let watermark = watermarkImage else { return pixelBuffer }

        let inputImage = CIImage(cvPixelBuffer: pixelBuffer)

        guard let compositeFilter = CIFilter(name: "CISourceOverCompositing") else { return pixelBuffer }
        compositeFilter.setValue(watermark, forKey: kCIInputImageKey)
        compositeFilter.setValue(inputImage, forKey: kCIInputBackgroundImageKey)

        guard let output = compositeFilter.outputImage else { return pixelBuffer }
        ciContext.render(output, to: pixelBuffer)
        return pixelBuffer
    }

    // MARK: - Watermark Image Construction

    private func buildWatermark(width: Int, height: Int) -> CIImage? {
        let fontSize = CGFloat(width) * 0.055
        let font = UIFont.boldSystemFont(ofSize: fontSize)

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: UIColor.white.withAlphaComponent(Constants.Watermark.opacity)
        ]

        let attributedText = NSAttributedString(string: Constants.Watermark.text, attributes: attrs)

        guard let filter = CIFilter(name: "CIAttributedTextImageGenerator") else {
            return fallbackWatermark(width: width, height: height, fontSize: fontSize)
        }

        filter.setValue(attributedText, forKey: "inputText")
        filter.setValue(NSNumber(value: 1.0), forKey: "inputScaleFactor")

        guard var textImage = filter.outputImage else {
            return fallbackWatermark(width: width, height: height, fontSize: fontSize)
        }

        // Position: bottom-right with padding
        let padding = CGFloat(width) * 0.04
        let textExtent = textImage.extent
        let x = CGFloat(width) - textExtent.width - padding
        let y = padding  // CoreImage origin is bottom-left

        textImage = textImage.transformed(by: CGAffineTransform(translationX: x, y: y))
        return textImage
    }

    /// Fallback watermark using a plain white rectangle with text via CGContext.
    private func fallbackWatermark(width: Int, height: Int, fontSize: CGFloat) -> CIImage? {
        let size = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            let attrs: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: UIColor.white.withAlphaComponent(Constants.Watermark.opacity)
            ]
            let text = Constants.Watermark.text as NSString
            let textSize = text.size(withAttributes: attrs)
            let padding = CGFloat(width) * 0.04
            let rect = CGRect(
                x: size.width - textSize.width - padding,
                y: size.height - textSize.height - padding,
                width: textSize.width,
                height: textSize.height
            )
            text.draw(in: rect, withAttributes: attrs)
        }
        return image.ciImage ?? CIImage(cgImage: image.cgImage!)
    }
}

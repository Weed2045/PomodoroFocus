import CoreImage
import UIKit

/// Stateless helper that applies CoreImage adjustments to a UIImage.
/// Uses a single shared CIContext (GPU-backed) for performance.
enum ImageProcessingService {

    private static let context = CIContext(options: [.useSoftwareRenderer: false])

    // MARK: – Public API

    /// Returns a new UIImage with filter, brightness, contrast and rotation applied.
    /// Heavy lifting is synchronous — call from a background Task when needed.
    static func apply(
        to source: UIImage,
        brightness: Float,
        contrast: Float,
        filter: ScanFilter,
        rotationDegrees: Double
    ) -> UIImage {
        AppLogger.image.debug("🖼 apply — filter=\(filter.rawValue, privacy: .public) brightness=\(brightness, privacy: .public) contrast=\(contrast, privacy: .public) rotation=\(rotationDegrees, privacy: .public)°")

        guard var ci = CIImage(image: source) else {
            AppLogger.image.error("❌ CIImage init failed for source image")
            return source
        }

        // 1 – Colour filter
        ci = applyColourFilter(ci, filter: filter)

        // 2 – Brightness / contrast (skip when values are neutral)
        if brightness != 0 || contrast != 1 {
            ci = applyColorControls(ci, brightness: brightness, contrast: contrast)
        }

        // 3 – Render via CIContext → CGImage → UIImage
        guard let cgImg = context.createCGImage(ci, from: ci.extent) else {
            AppLogger.image.error("❌ CIContext render failed")
            return source
        }
        var result = UIImage(cgImage: cgImg, scale: source.scale, orientation: .up)

        // 4 – Rotation (done in UIKit after CIContext render)
        if rotationDegrees != 0 {
            result = rotated(result, degrees: rotationDegrees)
        }
        AppLogger.image.debug("✅ apply complete — output size=\(result.size.width, privacy: .public)×\(result.size.height, privacy: .public)")
        return result
    }

    // MARK: – Private: Colour filters

    private static func applyColourFilter(_ ci: CIImage, filter: ScanFilter) -> CIImage {
        switch filter {
        case .original:
            return ci

        case .grayscale:
            let params: [String: Any] = [
                kCIInputImageKey:    ci,
                kCIInputColorKey:    CIColor(red: 0.65, green: 0.65, blue: 0.65),
                kCIInputIntensityKey: 1.0
            ]
            return CIFilter(name: "CIColorMonochrome", parameters: params)?.outputImage ?? ci

        case .blackWhite:
            // Step 1 – desaturate + boost contrast to produce near-B&W
            let step1Params: [String: Any] = [
                kCIInputImageKey:  ci,
                "inputSaturation": 0.0,
                "inputContrast":   1.6,
                "inputBrightness": 0.05
            ]
            let step1 = CIFilter(name: "CIColorControls", parameters: step1Params)?.outputImage ?? ci

            // Step 2 – hard threshold → pure black or white (available iOS 14+)
            let step2Params: [String: Any] = [
                kCIInputImageKey:  step1,
                "inputThreshold":  0.55
            ]
            return CIFilter(name: "CIColorThreshold", parameters: step2Params)?.outputImage ?? step1
        }
    }

    // MARK: – Private: Brightness / Contrast

    private static func applyColorControls(_ ci: CIImage, brightness: Float, contrast: Float) -> CIImage {
        let params: [String: Any] = [
            kCIInputImageKey:  ci,
            "inputBrightness": brightness,
            "inputContrast":   contrast,
            "inputSaturation": 1.0
        ]
        return CIFilter(name: "CIColorControls", parameters: params)?.outputImage ?? ci
    }

    // MARK: – Private: Rotation

    private static func rotated(_ image: UIImage, degrees: Double) -> UIImage {
        let radians = CGFloat(degrees * .pi / 180.0)
        // Swap canvas dimensions only for 90° / 270° rotations — not for 180° or any
        // non-right-angle value.  Previous `% 180 != 0` was also true for 45°, 135° etc.
        let normalised = ((Int(degrees) % 360) + 360) % 360
        let isOrthogonal = normalised == 90 || normalised == 270

        let newSize: CGSize = isOrthogonal
            ? CGSize(width: image.size.height, height: image.size.width)
            : image.size

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { ctx in
            ctx.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            ctx.cgContext.rotate(by: radians)
            image.draw(in: CGRect(
                x: -image.size.width  / 2,
                y: -image.size.height / 2,
                width:  image.size.width,
                height: image.size.height
            ))
        }
    }
}

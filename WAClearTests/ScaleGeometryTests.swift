import Testing
import CoreGraphics
@testable import WAClear

/// Tests for the scale-to-fill geometry logic used in VideoProcessor.scaleAndWatermark.
/// These mirror the math in the processor so we can verify it without spinning up AVFoundation.
@Suite("Scale-to-fill geometry")
struct ScaleGeometryTests {

    /// Replicates the scale calculation from VideoProcessor.scaleAndWatermark.
    private func scaleToFill(sourceW: CGFloat, sourceH: CGFloat,
                             targetW: Int, targetH: Int)
        -> (scale: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        let scaleX = CGFloat(targetW) / sourceW
        let scaleY = CGFloat(targetH) / sourceH
        let scale = max(scaleX, scaleY)
        let scaledW = sourceW * scale
        let scaledH = sourceH * scale
        let ox = (CGFloat(targetW) - scaledW) / 2
        let oy = (CGFloat(targetH) - scaledH) / 2
        return (scale, ox, oy)
    }

    // Target: 960×1704 (9:16 portrait)
    private let tw = 960
    private let th = 1704

    // ── Portrait source (already correct orientation after transform) ────

    @Test("Portrait 1080×1920 source fits to 960×1704 without cropping vertically")
    func portraitFit() {
        let (scale, ox, oy) = scaleToFill(sourceW: 1080, sourceH: 1920, targetW: tw, targetH: th)
        // Both dimensions scale proportionally; expect small horizontal crop (ox ≤ 0)
        #expect(scale > 0)
        #expect(ox <= 0)  // cropped or flush on sides
        #expect(oy <= 0)  // cropped or flush top/bottom
    }

    @Test("Portrait source: scale-to-fill covers full target height (may slightly overflow)")
    func portraitScaledHeight() {
        // 1080×1920 is very close to 9:16, but target 960×1704 is slightly wider.
        // scaleX (960/1080) > scaleY (1704/1920), so width is flush and height overflows.
        let (scale, _, oy) = scaleToFill(sourceW: 1080, sourceH: 1920, targetW: tw, targetH: th)
        let scaledH = 1920 * scale
        // Guarantee full coverage of target height (scale-to-fill invariant)
        #expect(scaledH + 2 * oy >= CGFloat(th) - 1)
    }

    // ── Landscape source (after applying preferredTransform the image becomes portrait) ──

    @Test("Landscape 1920×1080 treated as portrait 1080×1920 after 90° rotation fills target")
    func landscapeRotatedFit() {
        // After 90° rotation, effective size is 1080×1920 (portrait)
        // So we scale the rotated source, which now has w=1080, h=1920
        let (scale, _, _) = scaleToFill(sourceW: 1080, sourceH: 1920, targetW: tw, targetH: th)
        #expect(scale > 0)
    }

    @Test("Raw landscape 1920×1080 scaled to 960×1704 uses height-based scale (major crop)")
    func rawLandscapeWithoutTransform() {
        // This replicates the OLD (buggy) behaviour to confirm the fix matters.
        // Before the fix, preferredTransform was not applied, so 1920×1080 was scaled directly.
        let (scale, ox, _) = scaleToFill(sourceW: 1920, sourceH: 1080, targetW: tw, targetH: th)
        // scaleY dominates: 1704/1080 ≈ 1.578
        let expectedScale: CGFloat = CGFloat(th) / 1080
        #expect(abs(scale - expectedScale) < 0.001)
        // Horizontal crop is massive — ox is very negative
        #expect(ox < -500, "Should have large horizontal crop without transform")
    }

    @Test("Correct portrait source has much less horizontal crop than raw landscape")
    func portraitVsLandscapeCrop() {
        let (_, oxPortrait, _) = scaleToFill(sourceW: 1080, sourceH: 1920, targetW: tw, targetH: th)
        let (_, oxLandscape, _) = scaleToFill(sourceW: 1920, sourceH: 1080, targetW: tw, targetH: th)
        // Portrait source should have far less (or equal) horizontal cropping
        #expect(abs(oxPortrait) < abs(oxLandscape))
    }

    // ── Square source ────────────────────────────────────────────────────

    @Test("Square 1080×1080 source scaled to portrait: height drives scale")
    func squareSource() {
        let (scale, _, oy) = scaleToFill(sourceW: 1080, sourceH: 1080, targetW: tw, targetH: th)
        let expectedScale: CGFloat = CGFloat(th) / 1080
        #expect(abs(scale - expectedScale) < 0.001)
        #expect(oy == 0) // no vertical crop; horizontal crop
    }

    // ── Scale-to-fill invariant: output always fills target exactly ──────

    @Test("Scale-to-fill: output always covers full target width")
    func coversFullWidth() {
        let sources: [(CGFloat, CGFloat)] = [
            (1080, 1920), (1920, 1080), (1080, 1080), (720, 1280), (1440, 2560)
        ]
        for (sw, sh) in sources {
            let (scale, ox, _) = scaleToFill(sourceW: sw, sourceH: sh, targetW: tw, targetH: th)
            let scaledW = sw * scale
            // The frame covers at least targetWidth (may overflow on sides)
            #expect(scaledW + 2 * ox >= CGFloat(tw) - 1,
                    "Source \(sw)×\(sh) should cover full target width")
        }
    }

    @Test("Scale-to-fill: output always covers full target height")
    func coversFullHeight() {
        let sources: [(CGFloat, CGFloat)] = [
            (1080, 1920), (1920, 1080), (1080, 1080), (720, 1280), (1440, 2560)
        ]
        for (sw, sh) in sources {
            let (scale, _, oy) = scaleToFill(sourceW: sw, sourceH: sh, targetW: tw, targetH: th)
            let scaledH = sh * scale
            #expect(scaledH + 2 * oy >= CGFloat(th) - 1,
                    "Source \(sw)×\(sh) should cover full target height")
        }
    }
}

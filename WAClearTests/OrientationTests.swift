import Testing
import Foundation
import CoreGraphics
@testable import WAClear

// MARK: - CGSize.applying(preferredTransform:)

@Suite("CGSize orientation helpers")
struct CGSizeOrientationTests {

    // Typical iPhone portrait video: stored 1920×1080, rotated 90° to display as 1080×1920
    // preferredTransform for 90° CCW rotation in Quartz: (0, -1, 1, 0, 0, width)
    // However, the exact transform varies by recording direction; we test the
    // effectiveSize reflects the correct portrait/landscape interpretation.

    @Test("Identity transform preserves size")
    func identityPreservesSize() {
        let size = CGSize(width: 1920, height: 1080)
        let effective = size.applying(preferredTransform: .identity)
        #expect(effective.width == 1920)
        #expect(effective.height == 1080)
    }

    @Test("90° rotation swaps width and height")
    func ninetyDegreeRotation() {
        let size = CGSize(width: 1920, height: 1080)
        // CGAffineTransform.init(rotationAngle:) for 90° (π/2)
        let t = CGAffineTransform(rotationAngle: .pi / 2)
        let effective = size.applying(preferredTransform: t)
        // After 90° rotation the effective dimensions swap
        #expect(abs(effective.width  - 1080) < 1)
        #expect(abs(effective.height - 1920) < 1)
    }

    @Test("180° rotation preserves dimensions")
    func oneEightyDegrees() {
        let size = CGSize(width: 1920, height: 1080)
        let t = CGAffineTransform(rotationAngle: .pi)
        let effective = size.applying(preferredTransform: t)
        #expect(abs(effective.width  - 1920) < 1)
        #expect(abs(effective.height - 1080) < 1)
    }

    @Test("270° rotation swaps width and height")
    func twoSeventyDegrees() {
        let size = CGSize(width: 1920, height: 1080)
        let t = CGAffineTransform(rotationAngle: 3 * .pi / 2)
        let effective = size.applying(preferredTransform: t)
        #expect(abs(effective.width  - 1080) < 1)
        #expect(abs(effective.height - 1920) < 1)
    }

    @Test("Portrait-stored video: natural 1080×1920, identity → isPortrait")
    func portraitNatural() {
        let size = CGSize(width: 1080, height: 1920)
        #expect(size.applying(preferredTransform: .identity).isPortrait)
    }

    @Test("Landscape-stored video: natural 1920×1080, identity → not portrait")
    func landscapeNatural() {
        let size = CGSize(width: 1920, height: 1080)
        #expect(!size.applying(preferredTransform: .identity).isPortrait)
    }

    @Test("Landscape-stored + 90° rotation → portrait effective size")
    func landscapeRotatedToPortrait() {
        let size = CGSize(width: 1920, height: 1080)
        let t = CGAffineTransform(rotationAngle: .pi / 2)
        #expect(size.applying(preferredTransform: t).isPortrait)
    }
}

// MARK: - VideoProject orientation

@Suite("VideoProject orientation detection")
struct VideoProjectOrientationTests {

    @Test("Portrait natural size → isPortrait = true")
    func portraitNaturalSize() {
        let p = VideoProject(
            sourceURL: URL(filePath: "/dev/null"),
            duration: 60,
            naturalSize: CGSize(width: 1080, height: 1920),
            preferredTransform: .identity,
            hasAudio: false
        )
        #expect(p.isPortrait)
    }

    @Test("Landscape natural size → isPortrait = false")
    func landscapeNaturalSize() {
        let p = VideoProject(
            sourceURL: URL(filePath: "/dev/null"),
            duration: 60,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: .identity,
            hasAudio: false
        )
        #expect(!p.isPortrait)
    }

    @Test("Landscape natural size + 90° rotation → isPortrait = true")
    func landscapeWithRotation() {
        let p = VideoProject(
            sourceURL: URL(filePath: "/dev/null"),
            duration: 60,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: CGAffineTransform(rotationAngle: .pi / 2),
            hasAudio: false
        )
        #expect(p.isPortrait)
    }

    @Test("effectiveSize for landscape + 90° rotation is portrait dimensions")
    func effectiveSizeLandscapeRotated() {
        let p = VideoProject(
            sourceURL: URL(filePath: "/dev/null"),
            duration: 60,
            naturalSize: CGSize(width: 1920, height: 1080),
            preferredTransform: CGAffineTransform(rotationAngle: .pi / 2),
            hasAudio: false
        )
        let eff = p.effectiveSize
        // After rotation width and height should be swapped (within floating point tolerance)
        #expect(abs(eff.width  - 1080) < 1)
        #expect(abs(eff.height - 1920) < 1)
    }

    @Test("Square frame is not portrait (height == width)")
    func squareFrame() {
        let p = VideoProject(
            sourceURL: URL(filePath: "/dev/null"),
            duration: 60,
            naturalSize: CGSize(width: 1080, height: 1080),
            preferredTransform: .identity,
            hasAudio: false
        )
        // isPortrait requires height > width
        #expect(!p.isPortrait)
    }
}

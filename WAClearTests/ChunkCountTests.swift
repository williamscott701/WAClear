import Testing
import Foundation
import CoreGraphics
@testable import WAClear

// MARK: - Helper

private func makeProject(duration: Double,
                         naturalSize: CGSize = CGSize(width: 1080, height: 1920),
                         transform: CGAffineTransform = .identity) -> VideoProject {
    VideoProject(
        sourceURL: URL(filePath: "/dev/null"),
        duration: duration,
        naturalSize: naturalSize,
        preferredTransform: transform,
        hasAudio: true
    )
}

// MARK: - VideoProject.chunkCount(chunkDuration:)

@Suite("VideoProject chunk count")
struct VideoProjectChunkCountTests {

    // ── 60-second splits ───────────────────────────────────────────────────

    @Test("Exact multiple: 120 s / 60 s = 2")
    func exactMultiple60() {
        #expect(makeProject(duration: 120).chunkCount(chunkDuration: 60) == 2)
    }

    @Test("Non-exact: 90 s / 60 s = 2 (ceiling)")
    func nonExact60() {
        #expect(makeProject(duration: 90).chunkCount(chunkDuration: 60) == 2)
    }

    @Test("Just over: 61 s / 60 s = 2")
    func justOver60() {
        #expect(makeProject(duration: 61).chunkCount(chunkDuration: 60) == 2)
    }

    @Test("Exactly one: 60 s / 60 s = 1")
    func exactlyOne60() {
        #expect(makeProject(duration: 60).chunkCount(chunkDuration: 60) == 1)
    }

    @Test("Short video: 45 s / 60 s = 1 (min 1)")
    func short60() {
        #expect(makeProject(duration: 45).chunkCount(chunkDuration: 60) == 1)
    }

    @Test("10 min / 60 s = 10")
    func longVideo60() {
        #expect(makeProject(duration: 600).chunkCount(chunkDuration: 60) == 10)
    }

    // ── 30-second splits (the reported bug) ───────────────────────────────

    @Test("30 s: 120 s video = 4 chunks")
    func thirtySecond120s() {
        #expect(makeProject(duration: 120).chunkCount(chunkDuration: 30) == 4)
    }

    @Test("30 s: 90 s video = 3 chunks")
    func thirtySecond90s() {
        #expect(makeProject(duration: 90).chunkCount(chunkDuration: 30) == 3)
    }

    @Test("30 s: 60 s video = 2 chunks")
    func thirtySecond60s() {
        #expect(makeProject(duration: 60).chunkCount(chunkDuration: 30) == 2)
    }

    @Test("30 s: 31 s video = 2 (ceiling)")
    func thirtySecondJustOver() {
        #expect(makeProject(duration: 31).chunkCount(chunkDuration: 30) == 2)
    }

    @Test("30 s: 15 s video = 1 (min 1)")
    func thirtySecondShort() {
        #expect(makeProject(duration: 15).chunkCount(chunkDuration: 30) == 1)
    }

    @Test("10 min / 30 s = 20 chunks")
    func longVideo30() {
        #expect(makeProject(duration: 600).chunkCount(chunkDuration: 30) == 20)
    }

    // ── 30 s vs 60 s ratio ────────────────────────────────────────────────

    @Test("4-min video: 30 s splits produces double the chunks of 60 s splits")
    func halfDurationDoubleChunks() {
        let p = makeProject(duration: 240)
        #expect(p.chunkCount(chunkDuration: 30) == p.chunkCount(chunkDuration: 60) * 2)
    }

    // ── Edge cases ────────────────────────────────────────────────────────

    @Test("Zero-duration returns 1")
    func zeroDuration() {
        #expect(makeProject(duration: 0).chunkCount(chunkDuration: 60) == 1)
    }

    @Test("Negative duration returns 1")
    func negativeDuration() {
        #expect(makeProject(duration: -5).chunkCount(chunkDuration: 60) == 1)
    }

    @Test("Fractional: 90.1 s / 60 s = 2")
    func fractionalDuration() {
        #expect(makeProject(duration: 90.1).chunkCount(chunkDuration: 60) == 2)
    }

    @Test("Tiny video (1 s) / 60 s = 1")
    func tinyVideo() {
        #expect(makeProject(duration: 1).chunkCount(chunkDuration: 60) == 1)
    }
}

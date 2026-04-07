import Testing
@testable import WAClear

// MARK: - ProcessingProgress.overallProgress

@Suite("ProcessingProgress overall progress")
struct ProcessingProgressTests {

    @Test("First chunk, 0% done → overallProgress = 0")
    func firstChunkZero() {
        let p = ProcessingProgress(currentChunk: 1, totalChunks: 4, chunkProgress: 0)
        #expect(p.overallProgress == 0)
    }

    @Test("First chunk, 50% done → overallProgress = 0.125 (1/8)")
    func firstChunkHalf() {
        let p = ProcessingProgress(currentChunk: 1, totalChunks: 4, chunkProgress: 0.5)
        #expect(abs(p.overallProgress - 0.125) < 0.001)
    }

    @Test("First chunk, 100% done → overallProgress = 0.25")
    func firstChunkFull() {
        let p = ProcessingProgress(currentChunk: 1, totalChunks: 4, chunkProgress: 1.0)
        #expect(abs(p.overallProgress - 0.25) < 0.001)
    }

    @Test("Second chunk, 0% done → overallProgress = 0.25")
    func secondChunkZero() {
        let p = ProcessingProgress(currentChunk: 2, totalChunks: 4, chunkProgress: 0)
        #expect(abs(p.overallProgress - 0.25) < 0.001)
    }

    @Test("Second chunk, 50% done → overallProgress = 0.375")
    func secondChunkHalf() {
        let p = ProcessingProgress(currentChunk: 2, totalChunks: 4, chunkProgress: 0.5)
        #expect(abs(p.overallProgress - 0.375) < 0.001)
    }

    @Test("Last chunk, 100% done → overallProgress = 1.0")
    func lastChunkFull() {
        let p = ProcessingProgress(currentChunk: 4, totalChunks: 4, chunkProgress: 1.0)
        #expect(abs(p.overallProgress - 1.0) < 0.001)
    }

    @Test("Single chunk, 50% done → overallProgress = 0.5")
    func singleChunkHalf() {
        let p = ProcessingProgress(currentChunk: 1, totalChunks: 1, chunkProgress: 0.5)
        #expect(abs(p.overallProgress - 0.5) < 0.001)
    }

    @Test("Single chunk, 100% done → overallProgress = 1.0")
    func singleChunkFull() {
        let p = ProcessingProgress(currentChunk: 1, totalChunks: 1, chunkProgress: 1.0)
        #expect(abs(p.overallProgress - 1.0) < 0.001)
    }

    @Test("overallProgress is always in [0, 1] range (spot check)")
    func rangeCheck() {
        let cases: [(cur: Int, total: Int, prog: Double)] = [
            (1, 3, 0.0), (2, 3, 0.33), (3, 3, 1.0),
            (1, 10, 0.0), (5, 10, 0.5), (10, 10, 1.0)
        ]
        for (cur, total, prog) in cases {
            let p = ProcessingProgress(currentChunk: cur, totalChunks: total, chunkProgress: prog)
            #expect(p.overallProgress >= 0 && p.overallProgress <= 1)
        }
    }
}

// MARK: - ChunkProgressState computed properties

@Suite("ChunkProgressState computed properties")
struct ChunkProgressStateTests {

    private func state(id: Int, start: Double, end: Double) -> ChunkProgressState {
        ChunkProgressState(id: id, startTime: start, endTime: end, progress: 0, status: .pending, thumbnail: nil)
    }

    @Test("partNumber = id + 1")
    func partNumber() {
        #expect(state(id: 0, start: 0, end: 30).partNumber == 1)
        #expect(state(id: 1, start: 30, end: 60).partNumber == 2)
        #expect(state(id: 9, start: 270, end: 300).partNumber == 10)
    }

    @Test("duration = endTime - startTime")
    func duration() {
        #expect(state(id: 0, start: 0, end: 30).duration == 30)
        #expect(state(id: 0, start: 60, end: 90).duration == 30)
        #expect(state(id: 0, start: 0, end: 60).duration == 60)
    }

    @Test("formattedRange uses mmss format")
    func formattedRange() {
        let s = state(id: 0, start: 0, end: 60)
        #expect(s.formattedRange == "0:00 → 1:00")
    }

    @Test("formattedRange for second chunk (30 s splits)")
    func formattedRangeSecondChunk() {
        let s = state(id: 1, start: 30, end: 60)
        #expect(s.formattedRange == "0:30 → 1:00")
    }

    @Test("formattedDuration for 30 s chunk")
    func formattedDuration30s() {
        let s = state(id: 0, start: 0, end: 30)
        #expect(s.formattedDuration == "30s")
    }

    @Test("formattedDuration for 60 s chunk")
    func formattedDuration60s() {
        let s = state(id: 0, start: 0, end: 60)
        #expect(s.formattedDuration == "1m")
    }
}

// MARK: - ConversionSettings defaults

@Suite("ConversionSettings defaults match spec")
struct ConversionSettingsTests {

    @Test("Default target resolution is 960×1704")
    func targetResolution() {
        let s = ConversionSettings.default
        #expect(s.targetWidth == 960)
        #expect(s.targetHeight == 1704)
    }

    @Test("Default video bitrate is 1.8 Mbps")
    func videoBitrate() {
        #expect(ConversionSettings.default.videoBitrate == 1_800_000)
    }

    @Test("Default audio bitrate is 128 kbps")
    func audioBitrate() {
        #expect(ConversionSettings.default.audioBitrate == 128_000)
    }

    @Test("Default audio sample rate is 44.1 kHz")
    func audioSampleRate() {
        #expect(ConversionSettings.default.audioSampleRate == 44100)
    }

    @Test("Default audio channels is 2 (stereo)")
    func audioChannels() {
        #expect(ConversionSettings.default.audioChannels == 2)
    }

    @Test("Default frame rate is 30 fps")
    func frameRate() {
        #expect(ConversionSettings.default.frameRate == 30)
    }

    @Test("Default chunk duration is 60 seconds")
    func chunkDuration() {
        #expect(ConversionSettings.default.chunkDuration == 60)
    }

    @Test("Default adds watermark (free tier)")
    func addWatermark() {
        #expect(ConversionSettings.default.addWatermark == true)
    }

    @Test("Max keyframe interval equals frame rate × 2 (2-second GOP)")
    func keyframeInterval() {
        let s = ConversionSettings.default
        // GOP = 60 frames = 2 seconds at 30 fps
        #expect(s.maxKeyframeInterval == Int(s.frameRate) * 2)
    }

    @Test("One 60 s chunk at 1.8 Mbps + 128 kbps audio stays under 16 MB")
    func chunkFitsInWhatsAppLimit() {
        let s = ConversionSettings.default
        let videoBitsPerChunk = Double(s.videoBitrate) * s.chunkDuration
        let audioBitsPerChunk = Double(s.audioBitrate) * s.chunkDuration
        let totalBytes = (videoBitsPerChunk + audioBitsPerChunk) / 8
        let limitBytes: Double = 16 * 1024 * 1024
        #expect(totalBytes < limitBytes)
    }
}

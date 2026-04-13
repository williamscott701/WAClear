import Foundation
import AVFoundation
import CoreImage
import CoreVideo
import CoreGraphics

// MARK: - Processing Progress

struct ProcessingProgress: Sendable {
    let currentChunk: Int      // 1-based
    let totalChunks: Int
    let chunkProgress: Double  // 0...1 within current chunk

    var overallProgress: Double {
        let done = Double(currentChunk - 1)
        return (done + chunkProgress) / Double(totalChunks)
    }
}

// MARK: - VideoProcessor

final class VideoProcessor: @unchecked Sendable {
    private var _cancelled = false
    private let lock = NSLock()

    var isCancelled: Bool {
        lock.withLock { _cancelled }
    }

    func cancel() {
        lock.withLock { _cancelled = true }
    }

    // MARK: - Public API

    func process(
        project: VideoProject,
        settings: ConversionSettings,
        excludedChunks: Set<Int> = [],
        onProgress: @Sendable @escaping (ProcessingProgress) -> Void
    ) async throws -> [ChunkResult] {
        lock.withLock { _cancelled = false }

        // Dynamically choose portrait vs landscape target resolution based on source
        let effectiveSettings = Self.resolvedSettings(settings, for: project)

        let watermarkRenderer: WatermarkRenderer? = effectiveSettings.addWatermark ? WatermarkRenderer() : nil
        watermarkRenderer?.prepare(targetWidth: effectiveSettings.targetWidth, targetHeight: effectiveSettings.targetHeight)

        let totalChunksInVideo = project.chunkCount(chunkDuration: effectiveSettings.chunkDuration)
        let selectedIndices = (0..<totalChunksInVideo).filter { !excludedChunks.contains($0) }
        let totalToProcess = selectedIndices.count

        var results: [ChunkResult] = []
        var writtenURLs: [URL] = []

        do {
            for (progressIndex, index) in selectedIndices.enumerated() {
                if isCancelled { throw VideoError.cancelled }

                let startTime = Double(index) * effectiveSettings.chunkDuration
                let endTime = min(startTime + effectiveSettings.chunkDuration, project.duration)
                let chunkDuration = endTime - startTime

                let outputURL = URL.tempFileURL(prefix: "waclear_chunk")
                writtenURLs.append(outputURL)

                try await processChunk(
                    project: project,
                    settings: effectiveSettings,
                    startTime: startTime,
                    chunkDuration: chunkDuration,
                    outputURL: outputURL,
                    watermarkRenderer: watermarkRenderer,
                    chunkIndex: progressIndex,
                    totalChunks: totalToProcess,
                    onProgress: onProgress
                )

                let fileSize = outputURL.fileSizeBytes
                results.append(ChunkResult(
                    outputURL: outputURL,
                    chunkIndex: index,
                    totalChunks: totalChunksInVideo,
                    duration: chunkDuration,
                    fileSizeBytes: fileSize
                ))
            }
        } catch {
            for url in writtenURLs {
                try? FileManager.default.removeItem(at: url)
            }
            throw error
        }

        return results
    }

    // MARK: - Chunk Processing

    private func processChunk(
        project: VideoProject,
        settings: ConversionSettings,
        startTime: Double,
        chunkDuration: Double,
        outputURL: URL,
        watermarkRenderer: WatermarkRenderer?,
        chunkIndex: Int,
        totalChunks: Int,
        onProgress: @Sendable @escaping (ProcessingProgress) -> Void
    ) async throws {
        let asset = AVURLAsset(url: project.sourceURL)

        // --- Reader ---
        let timeRange = CMTimeRange(
            start: .from(seconds: startTime),
            duration: .from(seconds: chunkDuration)
        )

        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = timeRange

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoError.noVideoTrack
        }

        let videoOutputSettings: [String: Any] = [
            String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA
        ]
        let videoOutput = AVAssetReaderTrackOutput(track: videoTrack, outputSettings: videoOutputSettings)
        videoOutput.alwaysCopiesSampleData = false
        guard reader.canAdd(videoOutput) else {
            throw VideoError.processingFailed("Cannot add video output to reader")
        }
        reader.add(videoOutput)

        var audioOutput: AVAssetReaderTrackOutput?
        if project.hasAudio,
           let audioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let audioOutputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatLinearPCM
            ]
            let aOut = AVAssetReaderTrackOutput(track: audioTrack, outputSettings: audioOutputSettings)
            aOut.alwaysCopiesSampleData = false
            if reader.canAdd(aOut) {
                reader.add(aOut)
                audioOutput = aOut
            }
        }

        // --- Writer ---
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        let videoCompression: [String: Any] = [
            AVVideoAverageBitRateKey: settings.videoBitrate,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: settings.maxKeyframeInterval,
            AVVideoExpectedSourceFrameRateKey: settings.frameRate,
            AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
        ]

        let videoInputSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: settings.targetWidth,
            AVVideoHeightKey: settings.targetHeight,
            AVVideoCompressionPropertiesKey: videoCompression,
            AVVideoScalingModeKey: AVVideoScalingModeResizeAspectFill
        ]

        let videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoInputSettings)
        videoInput.expectsMediaDataInRealTime = false

        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: [
                String(kCVPixelBufferPixelFormatTypeKey): kCVPixelFormatType_32BGRA,
                String(kCVPixelBufferWidthKey): settings.targetWidth,
                String(kCVPixelBufferHeightKey): settings.targetHeight
            ]
        )

        guard writer.canAdd(videoInput) else {
            throw VideoError.processingFailed("Cannot add video input to writer")
        }
        writer.add(videoInput)

        var audioInput: AVAssetWriterInput?
        if audioOutput != nil {
            let audioInputSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: settings.audioSampleRate,
                AVNumberOfChannelsKey: settings.audioChannels,
                AVEncoderBitRateKey: settings.audioBitrate
            ]
            let aIn = AVAssetWriterInput(mediaType: .audio, outputSettings: audioInputSettings)
            aIn.expectsMediaDataInRealTime = false
            if writer.canAdd(aIn) {
                writer.add(aIn)
                audioInput = aIn
            }
        }

        // --- Start ---
        guard reader.startReading() else {
            let msg = reader.error?.localizedDescription ?? "unknown error"
            throw VideoError.processingFailed("Reader failed to start: \(msg)")
        }
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)

        let ciContext = CIContext(options: [.workingColorSpace: CGColorSpaceCreateDeviceRGB()])

        // Bundle all non-Sendable AVFoundation objects into a single @unchecked Sendable
        // container so the @Sendable closures passed to requestMediaDataWhenReady capture
        // only one value instead of seven individually-flagged non-Sendable types.
        let pipeline = ChunkPipeline(
            reader: reader,
            writer: writer,
            videoInput: videoInput,
            videoOutput: videoOutput,
            pixelBufferAdaptor: pixelBufferAdaptor,
            pool: pixelBufferAdaptor.pixelBufferPool,
            audioInput: audioInput,
            audioOutput: audioOutput
        )

        // Capture needed values for closures
        let targetWidth = settings.targetWidth
        let targetHeight = settings.targetHeight
        let preferredTransform = project.preferredTransform
        let cancelled = { [weak self] in self?.isCancelled ?? false }

        // --- Process video and audio concurrently via continuations ---
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let videoQueue = DispatchQueue(label: "com.waclear.video", qos: .userInitiated)
            let audioQueue = DispatchQueue(label: "com.waclear.audio", qos: .userInitiated)

            var videoFinished = false
            var audioFinished = pipeline.audioOutput == nil
            var resumedContinuation = false
            let finishLock = NSLock()

            func finishIfReady() {
                finishLock.withLock {
                    guard videoFinished && audioFinished && !resumedContinuation else { return }
                    resumedContinuation = true
                    pipeline.writer.finishWriting {
                        if let err = pipeline.writer.error {
                            continuation.resume(throwing: VideoError.processingFailed(err.localizedDescription))
                        } else {
                            continuation.resume()
                        }
                    }
                }
            }

            func abortWith(error: Error) {
                finishLock.withLock {
                    guard !resumedContinuation else { return }
                    resumedContinuation = true
                    pipeline.reader.cancelReading()
                    pipeline.writer.cancelWriting()
                    continuation.resume(throwing: error)
                }
            }

            // Video
            pipeline.videoInput.requestMediaDataWhenReady(on: videoQueue) {
                while pipeline.videoInput.isReadyForMoreMediaData {
                    if cancelled() {
                        abortWith(error: VideoError.cancelled)
                        return
                    }
                    guard let sample = pipeline.videoOutput.copyNextSampleBuffer() else {
                        pipeline.videoInput.markAsFinished()
                        videoFinished = true
                        finishIfReady()
                        return
                    }

                    let pts = CMSampleBufferGetPresentationTimeStamp(sample)
                    let rawProgress = max(0, min(pts.seconds - startTime, chunkDuration))
                    let chunkProg = chunkDuration > 0 ? rawProgress / chunkDuration : 0
                    let progress = ProcessingProgress(
                        currentChunk: chunkIndex + 1,
                        totalChunks: totalChunks,
                        chunkProgress: chunkProg
                    )
                    Task { @MainActor in onProgress(progress) }

                    guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }

                    let processed = Self.scaleAndWatermark(
                        pixelBuffer: pixelBuffer,
                        preferredTransform: preferredTransform,
                        watermarkRenderer: watermarkRenderer,
                        targetWidth: targetWidth,
                        targetHeight: targetHeight,
                        ciContext: ciContext,
                        pool: pipeline.pool
                    )

                    // Time offset so chunk starts at zero
                    let offsetPTS = CMTimeSubtract(pts, .from(seconds: startTime))
                    pipeline.pixelBufferAdaptor.append(processed, withPresentationTime: offsetPTS)
                }
            }

            // Audio — access audioInput/audioOutput only through pipeline so the closure
            // captures only pipeline (@unchecked Sendable), not the bare non-Sendable locals.
            if pipeline.audioInput != nil {
                pipeline.audioInput?.requestMediaDataWhenReady(on: audioQueue) {
                    while pipeline.audioInput?.isReadyForMoreMediaData == true {
                        guard let sample = pipeline.audioOutput?.copyNextSampleBuffer() else {
                            pipeline.audioInput?.markAsFinished()
                            audioFinished = true
                            finishIfReady()
                            return
                        }

                        // Offset audio timestamps
                        var timingInfo = CMSampleTimingInfo()
                        CMSampleBufferGetSampleTimingInfo(sample, at: 0, timingInfoOut: &timingInfo)
                        timingInfo.presentationTimeStamp = CMTimeSubtract(
                            timingInfo.presentationTimeStamp,
                            .from(seconds: startTime)
                        )
                        var adjusted: CMSampleBuffer?
                        CMSampleBufferCreateCopyWithNewTiming(
                            allocator: nil,
                            sampleBuffer: sample,
                            sampleTimingEntryCount: 1,
                            sampleTimingArray: &timingInfo,
                            sampleBufferOut: &adjusted
                        )
                        if let adjusted {
                            pipeline.audioInput?.append(adjusted)
                        }
                    }
                }
            }
        }
    }

    // MARK: - Orientation-aware settings

    /// Swaps width/height when the source video is landscape so we output 1280×720 instead of 720×1280.
    private static func resolvedSettings(_ settings: ConversionSettings, for project: VideoProject) -> ConversionSettings {
        let isPortrait = project.isPortrait
        var resolved = settings
        let w = settings.targetWidth
        let h = settings.targetHeight
        let shorter = min(w, h)
        let longer  = max(w, h)
        resolved.targetWidth  = isPortrait ? shorter : longer
        resolved.targetHeight = isPortrait ? longer  : shorter
        return resolved
    }

    // MARK: - ChunkPipeline

    /// Bundles all non-Sendable AVFoundation pipeline objects into a single
    /// @unchecked Sendable value so they can be safely captured in the
    /// @Sendable closures passed to requestMediaDataWhenReady(on:using:).
    private struct ChunkPipeline: @unchecked Sendable {
        nonisolated(unsafe) let reader: AVAssetReader
        nonisolated(unsafe) let writer: AVAssetWriter
        nonisolated(unsafe) let videoInput: AVAssetWriterInput
        nonisolated(unsafe) let videoOutput: AVAssetReaderTrackOutput
        nonisolated(unsafe) let pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor
        nonisolated(unsafe) let pool: CVPixelBufferPool?
        nonisolated(unsafe) let audioInput: AVAssetWriterInput?
        nonisolated(unsafe) let audioOutput: AVAssetReaderTrackOutput?
    }

    // MARK: - Frame Scaling & Watermarking

    private static func scaleAndWatermark(
        pixelBuffer: CVPixelBuffer,
        preferredTransform: CGAffineTransform,
        watermarkRenderer: WatermarkRenderer?,
        targetWidth: Int,
        targetHeight: Int,
        ciContext: CIContext,
        pool: CVPixelBufferPool?
    ) -> CVPixelBuffer {
        // Start from raw pixel buffer — no display orientation applied yet.
        var source = CIImage(cvPixelBuffer: pixelBuffer)

        // Apply the track's preferred transform so we work in display orientation.
        // CIImage uses the same Quartz coordinate space as AVFoundation's preferredTransform,
        // so we can apply it directly. After rotation the extent origin may be non-zero;
        // translate back to (0, 0) so subsequent math is simple.
        source = source.transformed(by: preferredTransform)
        let origin = source.extent.origin
        if origin.x != 0 || origin.y != 0 {
            source = source.transformed(by: CGAffineTransform(translationX: -origin.x, y: -origin.y))
        }

        let sourceWidth  = source.extent.width
        let sourceHeight = source.extent.height

        let scaleX = CGFloat(targetWidth) / sourceWidth
        let scaleY = CGFloat(targetHeight) / sourceHeight
        // Scale-to-fill: use the larger scale factor, then crop to target
        let scale = max(scaleX, scaleY)

        let scaledW = sourceWidth * scale
        let scaledH = sourceHeight * scale
        let ox = (CGFloat(targetWidth) - scaledW) / 2
        let oy = (CGFloat(targetHeight) - scaledH) / 2

        let transform = CGAffineTransform(scaleX: scale, y: scale)
            .concatenating(CGAffineTransform(translationX: ox, y: oy))

        var image = source.transformed(by: transform)
            .cropped(to: CGRect(x: 0, y: 0, width: targetWidth, height: targetHeight))

        // Composite watermark on top
        if let watermark = watermarkRenderer {
            // We render the watermark directly on the scaled image
            let watermarked = watermark.applyWatermarkOnCIImage(image)
            image = watermarked
        }

        // Write to output pixel buffer
        var outputBuffer: CVPixelBuffer?
        if let pool {
            CVPixelBufferPoolCreatePixelBuffer(nil, pool, &outputBuffer)
        } else {
            CVPixelBufferCreate(nil, targetWidth, targetHeight, kCVPixelFormatType_32BGRA, nil, &outputBuffer)
        }

        if let out = outputBuffer {
            ciContext.render(image, to: out)
            return out
        }
        return pixelBuffer
    }
}

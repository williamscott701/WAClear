import Foundation
import Combine
import SwiftUI
import AVFoundation

// MARK: - ChunkProgressState

struct ChunkProgressState: Identifiable {
    let id: Int           // 0-based index
    let startTime: Double
    let endTime: Double
    var progress: Double  // 0...1
    var status: Status
    var thumbnail: UIImage?

    enum Status { case pending, processing, done }

    var partNumber: Int { id + 1 }
    var duration: Double { endTime - startTime }

    /// "0:00 → 1:00" — clear clock-style range
    var formattedRange: String { "\(startTime.mmss) → \(endTime.mmss)" }

    /// "60s" or "30s"
    var formattedDuration: String { duration.formattedDuration }
}

// MARK: - ProcessingViewModel

@MainActor
final class ProcessingViewModel: ObservableObject {
    @Published private(set) var progress = ProcessingProgress(currentChunk: 0, totalChunks: 1, chunkProgress: 0)
    @Published private(set) var chunkStates: [ChunkProgressState] = []
    @Published private(set) var isProcessing = false
    @Published private(set) var results: [ChunkResult] = []
    @Published var errorMessage: String?
    @Published var processingComplete = false

    private let processor = VideoProcessor()
    private var processingTask: Task<Void, Never>?

    var overallProgress: Double { progress.overallProgress }

    // MARK: - Start

    func startProcessing(
        project: VideoProject,
        settings: ConversionSettings,
        excludedChunks: Set<Int> = [],
        onSuccess: @escaping @MainActor () -> Void = {}
    ) {
        guard !isProcessing else { return }
        isProcessing = true
        processingComplete = false
        results = []
        errorMessage = nil

        let totalChunksInVideo = project.chunkCount(chunkDuration: settings.chunkDuration)
        let selectedIndices = (0..<totalChunksInVideo).filter { !excludedChunks.contains($0) }

        // Build per-chunk states only for selected chunks (keeping original index for labeling)
        chunkStates = selectedIndices.enumerated().map { progressIndex, originalIndex in
            let start = Double(originalIndex) * settings.chunkDuration
            let end = min(start + settings.chunkDuration, project.duration)
            return ChunkProgressState(
                id: progressIndex,
                startTime: start,
                endTime: end,
                progress: 0,
                status: progressIndex == 0 ? .processing : .pending,
                thumbnail: nil
            )
        }

        let totalToProcess = selectedIndices.count
        progress = ProcessingProgress(currentChunk: 1, totalChunks: totalToProcess, chunkProgress: 0)

        // Generate thumbnails from source video in the background
        Task { await generateThumbnails(sourceURL: project.sourceURL) }

        processingTask = Task {
            do {
                let chunks = try await processor.process(
                    project: project,
                    settings: settings,
                    excludedChunks: excludedChunks,
                    onProgress: { [weak self] prog in
                        Task { @MainActor [weak self] in
                            guard let self else { return }

                            let currentIdx = prog.currentChunk - 1
                            let prevIdx   = self.progress.currentChunk - 1

                            // Chunk just advanced — mark previous as done, activate new one
                            if prog.currentChunk > self.progress.currentChunk {
                                if prevIdx >= 0 && prevIdx < self.chunkStates.count {
                                    self.chunkStates[prevIdx].progress = 1.0
                                    self.chunkStates[prevIdx].status   = .done
                                }
                                if currentIdx < self.chunkStates.count {
                                    self.chunkStates[currentIdx].status = .processing
                                }
                            }

                            // Update live progress for active chunk
                            if currentIdx >= 0 && currentIdx < self.chunkStates.count {
                                self.chunkStates[currentIdx].progress = prog.chunkProgress
                            }

                            self.progress = prog
                        }
                    }
                )

                // All done — mark everything complete
                for i in 0..<chunkStates.count {
                    chunkStates[i].progress = 1.0
                    chunkStates[i].status   = .done
                }
                results = chunks
                isProcessing = false
                processingComplete = true
                onSuccess()

            } catch VideoError.cancelled {
                isProcessing = false
            } catch {
                errorMessage = error.localizedDescription
                isProcessing = false
            }
        }
    }

    // MARK: - Thumbnail Generation

    private func generateThumbnails(sourceURL: URL) async {
        let asset = AVURLAsset(url: sourceURL)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 200, height: 356)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter  = CMTime(seconds: 2, preferredTimescale: 600)

        for index in 0..<chunkStates.count {
            let chunk = chunkStates[index]
            // Sample 1s into the chunk (or mid-point for short chunks)
            let sampleOffset = min(1.0, chunk.duration / 2)
            let time = CMTime(seconds: chunk.startTime + sampleOffset, preferredTimescale: 600)

            if let cgImage = try? await gen.image(at: time).image {
                chunkStates[index].thumbnail = UIImage(cgImage: cgImage)
            }
        }
    }

    // MARK: - Cancel

    func cancel() {
        processor.cancel()
        processingTask?.cancel()
        processingTask = nil
        isProcessing = false
        FileManager.default.removeTempFiles(prefix: "waclear_chunk")
    }
}

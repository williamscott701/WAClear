import Foundation
import AVFoundation

// MARK: - Video Errors
enum VideoError: LocalizedError {
    case noVideoTrack
    case processingFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .noVideoTrack:
            return "The selected file does not contain a video track."
        case .processingFailed(let reason):
            return "Video processing failed: \(reason)"
        case .cancelled:
            return "Processing was cancelled."
        }
    }
}

// MARK: - VideoAnalyzer
struct VideoAnalyzer {
    func analyze(url: URL) async throws -> VideoProject {
        let asset = AVURLAsset(url: url)

        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw VideoError.noVideoTrack
        }

        async let durationTask = asset.load(.duration)
        async let naturalSizeTask = videoTrack.load(.naturalSize)
        async let preferredTransformTask = videoTrack.load(.preferredTransform)
        async let audioTracksTask = asset.loadTracks(withMediaType: .audio)

        let duration = try await durationTask
        let naturalSize = try await naturalSizeTask
        let preferredTransform = try await preferredTransformTask
        let audioTracks = try await audioTracksTask

        return VideoProject(
            sourceURL: url,
            duration: duration.seconds,
            naturalSize: naturalSize,
            preferredTransform: preferredTransform,
            hasAudio: !audioTracks.isEmpty
        )
    }
}

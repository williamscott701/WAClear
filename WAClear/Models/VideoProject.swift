import Foundation
import CoreGraphics

struct VideoProject: Identifiable, Sendable {
    let id: UUID
    let sourceURL: URL
    let duration: Double          // seconds
    let naturalSize: CGSize       // raw pixel dimensions from the video track
    let preferredTransform: CGAffineTransform
    let hasAudio: Bool

    /// Total number of chunks when splitting at the given duration.
    /// Always call this with the actual user-selected split duration;
    /// the old property was hardcoded to the 60 s constant and therefore
    /// produced wrong counts when the user chose 30 s splits.
    func chunkCount(chunkDuration: Double) -> Int {
        guard chunkDuration > 0 && duration > 0 else { return 1 }
        return max(1, Int(ceil(duration / chunkDuration)))
    }

    /// The effective display size (after applying the preferred transform).
    var effectiveSize: CGSize {
        naturalSize.applying(preferredTransform: preferredTransform)
    }

    var isPortrait: Bool {
        effectiveSize.isPortrait
    }

    init(
        id: UUID = UUID(),
        sourceURL: URL,
        duration: Double,
        naturalSize: CGSize,
        preferredTransform: CGAffineTransform,
        hasAudio: Bool
    ) {
        self.id = id
        self.sourceURL = sourceURL
        self.duration = duration
        self.naturalSize = naturalSize
        self.preferredTransform = preferredTransform
        self.hasAudio = hasAudio
    }
}

extension VideoProject: Hashable {
    static func == (lhs: VideoProject, rhs: VideoProject) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

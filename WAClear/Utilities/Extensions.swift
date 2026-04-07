import Foundation
import AVFoundation
import CoreMedia
import CoreGraphics

// MARK: - CMTime
extension CMTime {
    var seconds: Double {
        CMTimeGetSeconds(self)
    }

    static func from(seconds: Double, timescale: CMTimeScale = 600) -> CMTime {
        CMTimeMakeWithSeconds(seconds, preferredTimescale: timescale)
    }
}

// MARK: - URL
extension URL {
    static func tempFileURL(prefix: String = "chunk") -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("\(prefix)_\(UUID().uuidString).mp4")
    }

    var fileSizeBytes: Int64 {
        (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? Int64) ?? 0
    }

    var fileSizeMB: Double {
        Double(fileSizeBytes) / (1024 * 1024)
    }
}

// MARK: - FileManager
extension FileManager {
    func removeTempFiles(prefix: String) {
        let tmpDir = temporaryDirectory
        guard let files = try? contentsOfDirectory(at: tmpDir, includingPropertiesForKeys: nil) else { return }
        for file in files where file.lastPathComponent.hasPrefix(prefix) {
            try? removeItem(at: file)
        }
    }
}

// MARK: - CGSize
extension CGSize {
    /// Returns the effective display size after applying a preferred transform.
    func applying(preferredTransform transform: CGAffineTransform) -> CGSize {
        let rect = CGRect(origin: .zero, size: self).applying(transform)
        return CGSize(width: abs(rect.width), height: abs(rect.height))
    }

    var isPortrait: Bool { height > width }
}

// MARK: - Double (formatting)
extension Double {
    /// Human-readable duration: "45s", "1m 30s", "2m"
    var formattedDuration: String {
        let totalSeconds = Int(self)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        if minutes > 0 && seconds > 0 { return "\(minutes)m \(seconds)s" }
        if minutes > 0 { return "\(minutes)m" }
        return "\(seconds)s"
    }

    /// Clock-style timestamp: "0:00", "1:05", "12:34"
    var mmss: String {
        let totalSeconds = max(0, Int(self))
        let m = totalSeconds / 60
        let s = totalSeconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

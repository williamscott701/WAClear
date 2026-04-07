import Foundation

struct ChunkResult: Identifiable, Sendable {
    let id: UUID
    let outputURL: URL
    let chunkIndex: Int
    let totalChunks: Int
    let duration: Double
    let fileSizeBytes: Int64

    var partNumber: Int { chunkIndex + 1 }
    var fileSizeMB: Double { Double(fileSizeBytes) / (1024 * 1024) }

    var formattedDuration: String { duration.formattedDuration }

    var formattedFileSize: String {
        String(format: "%.1f MB", fileSizeMB)
    }

    init(
        id: UUID = UUID(),
        outputURL: URL,
        chunkIndex: Int,
        totalChunks: Int,
        duration: Double,
        fileSizeBytes: Int64
    ) {
        self.id = id
        self.outputURL = outputURL
        self.chunkIndex = chunkIndex
        self.totalChunks = totalChunks
        self.duration = duration
        self.fileSizeBytes = fileSizeBytes
    }
}

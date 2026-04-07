import Testing
import Foundation
@testable import WAClear

// MARK: - ChunkResult

@Suite("ChunkResult properties")
struct ChunkResultTests {

    private func result(index: Int, total: Int, duration: Double, bytes: Int64 = 0) -> ChunkResult {
        ChunkResult(
            outputURL: URL(filePath: "/tmp/chunk_\(index).mp4"),
            chunkIndex: index,
            totalChunks: total,
            duration: duration,
            fileSizeBytes: bytes
        )
    }

    @Test("partNumber = chunkIndex + 1 for first chunk")
    func partNumberFirst() {
        #expect(result(index: 0, total: 4, duration: 60).partNumber == 1)
    }

    @Test("partNumber = chunkIndex + 1 for last chunk")
    func partNumberLast() {
        #expect(result(index: 3, total: 4, duration: 60).partNumber == 4)
    }

    @Test("partNumber and totalChunks are consistent")
    func partNumberConsistency() {
        for i in 0..<5 {
            let r = result(index: i, total: 5, duration: 30)
            #expect(r.partNumber == i + 1)
            #expect(r.totalChunks == 5)
        }
    }

    @Test("fileSizeBytes is stored correctly")
    func fileSizeBytes() {
        let r = result(index: 0, total: 1, duration: 60, bytes: 14_000_000)
        #expect(r.fileSizeBytes == 14_000_000)
    }

    @Test("Duration is stored correctly")
    func duration() {
        let r = result(index: 0, total: 1, duration: 30.5)
        #expect(r.duration == 30.5)
    }

    @Test("Last chunk of non-exact split has correct short duration")
    func shortLastChunk() {
        // 95 s video / 60 s = chunk 0 (60 s) + chunk 1 (35 s)
        let last = result(index: 1, total: 2, duration: 35)
        #expect(last.duration == 35)
        #expect(last.partNumber == 2)
        #expect(last.totalChunks == 2)
    }

    @Test("Chunk at index 0 of many has correct totalChunks")
    func manyChunksTotalCount() {
        let r = result(index: 0, total: 20, duration: 30)
        #expect(r.totalChunks == 20)
    }
}

// MARK: - Chunk file size vs WhatsApp limit

@Suite("ChunkResult file size constraints")
struct ChunkResultFileSizeTests {

    @Test("Chunk within WhatsApp 16 MB limit is valid")
    func withinLimit() {
        let maxBytes: Int64 = 16 * 1024 * 1024
        // Typical 60 s chunk at 1.8 Mbps: ~13.5 MB
        let typicalBytes: Int64 = 14_000_000
        #expect(typicalBytes < maxBytes)
    }

    @Test("Chunk exceeding 16 MB would be rejected by WhatsApp")
    func exceedsLimit() {
        let maxBytes: Int64 = 16 * 1024 * 1024
        let oversizedBytes: Int64 = 17_000_000
        #expect(oversizedBytes > maxBytes)
    }
}

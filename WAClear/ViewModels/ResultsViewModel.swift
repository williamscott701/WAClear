import Foundation
import Combine
import SwiftUI
import Photos

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var chunks: [ChunkResult] = []
    @Published var isSaving = false
    @Published var saveMessage: String?
    @Published var showShareSheet = false
    @Published var shareItems: [Any] = []
    @Published var showSubscription = false
    @Published var savedChunkURLs: Set<URL> = []

    func setup(with chunks: [ChunkResult]) {
        self.chunks = chunks
    }

    // MARK: - Save All to Photos

    func saveAllToPhotos() async {
        guard await requestPhotoLibraryAccess() else { return }
        isSaving = true
        defer { isSaving = false }

        var savedCount = 0
        for chunk in chunks {
            do {
                try await PHPhotoLibrary.shared().performChanges {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: chunk.outputURL)
                }
                savedChunkURLs.insert(chunk.outputURL)
                savedCount += 1
            } catch {
                saveMessage = "Failed to save chunk \(chunk.partNumber): \(error.localizedDescription)"
                return
            }
        }
        saveMessage = "\(savedCount) video\(savedCount == 1 ? "" : "s") saved to Photos!"
    }

    // MARK: - Save Single Chunk

    func saveChunk(_ chunk: ChunkResult) async {
        guard !savedChunkURLs.contains(chunk.outputURL) else { return }
        guard await requestPhotoLibraryAccess() else { return }
        do {
            try await PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: chunk.outputURL)
            }
            savedChunkURLs.insert(chunk.outputURL)
        } catch {
            saveMessage = "Failed to save Part \(chunk.partNumber): \(error.localizedDescription)"
        }
    }

    // MARK: - Photos Authorization

    private func requestPhotoLibraryAccess() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        switch status {
        case .authorized, .limited:
            return true
        case .notDetermined:
            let granted = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
            if granted == .authorized || granted == .limited { return true }
            saveMessage = "Please allow Photos access in Settings to save videos."
            return false
        default:
            saveMessage = "Photos access is denied. Enable it in Settings > Privacy > Photos."
            return false
        }
    }

    // MARK: - Share

    func shareChunk(_ chunk: ChunkResult) {
        shareItems = [chunk.outputURL]
        showShareSheet = true
    }

    func shareAll() {
        shareItems = chunks.map(\.outputURL)
        showShareSheet = true
    }

    // MARK: - Cleanup

    func cleanup() {
        for chunk in chunks {
            try? FileManager.default.removeItem(at: chunk.outputURL)
        }
        chunks = []
    }
}

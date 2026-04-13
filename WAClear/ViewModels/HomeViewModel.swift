import Foundation
import Combine
import SwiftUI
import PhotosUI
import Photos

// MARK: - VideoPreviewInfo

struct VideoPreviewInfo {
    let duration: Double      // seconds; 0 if unknown
    let pixelWidth: Int
    let pixelHeight: Int
    let pendingItem: PhotosPickerItem

    var isKnown: Bool { duration > 0 }
    var isPortrait: Bool { pixelHeight >= pixelWidth }

    func chunkCount(splitDuration: Double) -> Int {
        guard duration > 0 else { return 1 }
        return max(1, Int(ceil(duration / splitDuration)))
    }
}

// MARK: - HomeViewModel

@MainActor
final class HomeViewModel: ObservableObject {
    @Published var showSettings = false
    @Published var selectedItem: PhotosPickerItem?
    @Published var videoPreview: VideoPreviewInfo?
    @Published var thumbnail: UIImage?
    @Published var splitDuration: Double = 30
    @Published var isPreparingFile = false   // true only during the brief VideoAnalyzer step
    @Published var isLoadingFile = false     // true while video file is being exported in background
    @Published var errorMessage: String?
    @Published var navigateTo: HomeNavigation?

    enum HomeNavigation: Hashable {
        case processing(VideoProject, splitDuration: Double)
    }

    private var loadingTask: Task<Void, Never>?
    private var eagerLoadTask: Task<Void, Never>?
    private(set) var loadedVideoURL: URL?

    // MARK: - Selection (instant metadata + thumbnail, then eager file export)

    func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        videoPreview = nil
        thumbnail = nil
        loadedVideoURL = nil
        eagerLoadTask?.cancel()
        eagerLoadTask = nil

        if let identifier = item.itemIdentifier {
            let result = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
            if let asset = result.firstObject {
                videoPreview = VideoPreviewInfo(
                    duration: asset.duration,
                    pixelWidth: asset.pixelWidth,
                    pixelHeight: asset.pixelHeight,
                    pendingItem: item
                )
                loadThumbnail(from: asset)
                startEagerLoad(item: item)
                return
            }
        }

        // Fallback: no PHAsset access — show card without stats, still kick off eager load
        videoPreview = VideoPreviewInfo(duration: 0, pixelWidth: 0, pixelHeight: 0, pendingItem: item)
        startEagerLoad(item: item)
    }

    private func loadThumbnail(from asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic
        options.resizeMode = .fast

        PHImageManager.default().requestImage(
            for: asset,
            targetSize: CGSize(width: 600, height: 1000),
            contentMode: .aspectFill,
            options: options
        ) { [weak self] image, _ in
            guard let image else { return }
            Task { @MainActor [weak self] in
                self?.thumbnail = image
            }
        }
    }

    private func startEagerLoad(item: PhotosPickerItem) {
        isLoadingFile = true
        eagerLoadTask = Task {
            do {
                guard let transferred = try await item.loadTransferable(type: VideoTransferable.self) else {
                    await MainActor.run { self.isLoadingFile = false }
                    return
                }
                try Task.checkCancellation()
                await MainActor.run {
                    self.loadedVideoURL = transferred.url
                    self.isLoadingFile = false
                }
            } catch is CancellationError {
                await MainActor.run { self.isLoadingFile = false }
            } catch {
                await MainActor.run { self.isLoadingFile = false }
            }
        }
    }

    // MARK: - Start (non-blocking, uses pre-loaded URL if available)

    func startProcessing() {
        guard let preview = videoPreview, !isPreparingFile else { return }

        loadingTask = Task {
            isPreparingFile = true

            do {
                let url: URL
                if let preloaded = loadedVideoURL {
                    url = preloaded
                } else {
                    // Eager load may still be in progress — wait for it
                    guard let transferred = try await preview.pendingItem
                        .loadTransferable(type: VideoTransferable.self) else {
                        isPreparingFile = false
                        errorMessage = "Could not load the video file."
                        return
                    }
                    url = transferred.url
                    loadedVideoURL = url
                }

                try Task.checkCancellation()

                let project = try await VideoAnalyzer().analyze(url: url)

                try Task.checkCancellation()

                isPreparingFile = false
                navigateTo = .processing(project, splitDuration: splitDuration)

            } catch is CancellationError {
                isPreparingFile = false
            } catch {
                isPreparingFile = false
                errorMessage = error.localizedDescription
            }
        }
    }

    func cancelLoading() {
        loadingTask?.cancel()
        loadingTask = nil
        isPreparingFile = false
    }

    // MARK: - Helpers

    func clearSelectedVideo() {
        cancelLoading()
        eagerLoadTask?.cancel()
        eagerLoadTask = nil
        videoPreview = nil
        thumbnail = nil
        selectedItem = nil
        loadedVideoURL = nil
        isLoadingFile = false
    }

    func clearError() {
        errorMessage = nil
    }
}

// MARK: - VideoTransferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let dest = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked_\(UUID().uuidString).mp4")
            try FileManager.default.copyItem(at: received.file, to: dest)
            return VideoTransferable(url: dest)
        }
    }
}

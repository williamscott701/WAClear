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
    @Published var splitDuration: Double = 60
    @Published var isPreparingFile = false
    @Published var errorMessage: String?
    @Published var navigateTo: HomeNavigation?

    enum HomeNavigation: Hashable {
        case processing(VideoProject, splitDuration: Double)
    }

    private var loadingTask: Task<Void, Never>?

    // MARK: - Selection (instant — PHAsset metadata + thumbnail, no file export)

    func handlePickedItem(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        videoPreview = nil
        thumbnail = nil

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
                return
            }
        }

        // Fallback: no PHAsset access — show card without stats or thumbnail
        videoPreview = VideoPreviewInfo(duration: 0, pixelWidth: 0, pixelHeight: 0, pendingItem: item)
    }

    private func loadThumbnail(from asset: PHAsset) {
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic   // show low-res preview immediately, upgrade later
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

    // MARK: - Start (non-blocking, cancellable)

    func startProcessing() {
        guard let preview = videoPreview, !isPreparingFile else { return }

        loadingTask = Task {
            isPreparingFile = true

            do {
                guard let url = try await preview.pendingItem
                    .loadTransferable(type: VideoTransferable.self)?.url else {
                    isPreparingFile = false
                    errorMessage = "Could not load the video file."
                    return
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
        videoPreview = nil
        thumbnail = nil
        selectedItem = nil
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

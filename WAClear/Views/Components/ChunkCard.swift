import SwiftUI
import AVFoundation

struct ChunkCard: View {
    let chunk: ChunkResult
    let isPremium: Bool
    let onShare: () -> Void
    let onRemoveWatermark: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottom) {
            // Thumbnail background
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .overlay {
                            Image(systemName: "video.fill")
                                .font(.largeTitle)
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }
            }
            .frame(width: 160, height: 284)
            .clipped()

            // Bottom info overlay
            VStack(alignment: .leading, spacing: 6) {
                Text("Part \(chunk.partNumber) of \(chunk.totalChunks)")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)

                HStack {
                    Label(chunk.formattedDuration, systemImage: "clock")
                    Spacer()
                    Label(chunk.formattedFileSize, systemImage: "arrow.down.circle")
                }
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.8))

                HStack {
                    if !isPremium {
                        WatermarkBadge(onTap: onRemoveWatermark)
                    }
                    Spacer()
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 32, height: 32)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                }
            }
            .padding(10)
            .background(
                LinearGradient(
                    colors: [.clear, .black.opacity(0.85)],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .frame(width: 160, height: 284)
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cardCornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: chunk.outputURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 320, height: 568)

        let time = CMTime(seconds: min(1, chunk.duration / 2), preferredTimescale: 600)
        if let cgImage = try? await imageGenerator.image(at: time).image {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }
}

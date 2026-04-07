import SwiftUI
import AVFoundation

/// A small card used in the "recent conversions" grid on the home screen.
struct VideoThumbnailCard: View {
    let chunk: ChunkResult

    @State private var thumbnail: UIImage?

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Rectangle()
                        .fill(Color.white.opacity(0.07))
                        .overlay {
                            Image(systemName: "video.fill")
                                .foregroundStyle(.white.opacity(0.3))
                        }
                }
            }
            .frame(width: 100, height: 178)
            .clipped()

            Text("Part \(chunk.partNumber)")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white)
                .padding(6)
                .background(.black.opacity(0.6))
        }
        .frame(width: 100, height: 178)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        let asset = AVURLAsset(url: chunk.outputURL)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 200, height: 356)
        let time = CMTime(seconds: 0.5, preferredTimescale: 600)
        if let cgImage = try? await gen.image(at: time).image {
            thumbnail = UIImage(cgImage: cgImage)
        }
    }
}

import SwiftUI

struct ResultsView: View {
    let chunks: [ChunkResult]

    @StateObject private var viewModel = ResultsViewModel()
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue   = Color(red: 0.20, green: 0.50, blue: 1.0)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Success header
                headerSection
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                // Per-chunk list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.chunks) { chunk in
                            ChunkRow(
                                chunk: chunk,
                                isSaved: viewModel.savedChunkURLs.contains(chunk.outputURL),
                                isPremium: storeManager.isPremium,
                                onSave: { await viewModel.saveChunk(chunk) },
                                onShare: { viewModel.shareChunk(chunk) },
                                onRemoveWatermark: { viewModel.showSubscription = true }
                            )
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)
                    .padding(.bottom, 12)
                }

                // Bottom action bar
                bottomActionBar
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                    .background(bgColor)
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    viewModel.cleanup()
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "xmark")
                        Text("Done")
                    }
                    .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .alert("Saved", isPresented: Binding(
            get: { viewModel.saveMessage != nil },
            set: { if !$0 { viewModel.saveMessage = nil } }
        )) {
            Button("OK") { viewModel.saveMessage = nil }
        } message: {
            Text(viewModel.saveMessage ?? "")
        }
        .sheet(isPresented: $viewModel.showSubscription) {
            SubscriptionView()
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            ShareSheet(items: viewModel.shareItems)
        }
        .onAppear { viewModel.setup(with: chunks) }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [purple, blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                Image(systemName: "checkmark")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
            }

            Text("Done!")
                .font(.system(size: 26, weight: .black))
                .foregroundStyle(.white)

            Text("\(chunks.count) part\(chunks.count == 1 ? "" : "s") ready for WhatsApp")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.55))
        }
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        VStack(spacing: 10) {
            GradientButton("Save All to Photos", systemImage: "square.and.arrow.down") {
                await viewModel.saveAllToPhotos()
            }

            Button { viewModel.shareAll() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Share All")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.white.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            }
        }
    }
}

// MARK: - Chunk Row

private struct ChunkRow: View {
    let chunk: ChunkResult
    let isSaved: Bool
    let isPremium: Bool
    let onSave: () async -> Void
    let onShare: () -> Void
    let onRemoveWatermark: () -> Void

    @State private var isSaving = false

    private let purple = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue   = Color(red: 0.20, green: 0.50, blue: 1.0)
    private let green  = Color(red: 0.20, green: 0.85, blue: 0.50)

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    LinearGradient(
                        colors: [purple.opacity(0.25), blue.opacity(0.25)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 52, height: 88)
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.white.opacity(0.35))
                }

            // Info
            VStack(alignment: .leading, spacing: 6) {
                Text("Part \(chunk.partNumber) of \(chunk.totalChunks)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(chunk.duration.formattedDuration)
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.65))

                    Text("·")
                        .foregroundStyle(.white.opacity(0.25))

                    Text(ByteCountFormatter.string(fromByteCount: chunk.fileSizeBytes, countStyle: .file))
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.45))
                }

                if !isPremium {
                    Button { onRemoveWatermark() } label: {
                        Label("Has watermark · Remove", systemImage: "drop.fill")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(purple)
                    }
                }
            }

            Spacer()

            // Per-chunk action buttons
            VStack(spacing: 8) {
                // Share button
                Button { onShare() } label: {
                    actionButtonLabel(
                        icon: "square.and.arrow.up",
                        label: "Share",
                        color: .white.opacity(0.8),
                        bg: Color.white.opacity(0.1)
                    )
                }

                // Save button
                Button {
                    guard !isSaved && !isSaving else { return }
                    isSaving = true
                    Task {
                        await onSave()
                        isSaving = false
                    }
                } label: {
                    if isSaving {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.1))
                                .frame(width: 54, height: 50)
                            ProgressView()
                                .progressViewStyle(.circular)
                                .tint(.white)
                                .scaleEffect(0.75)
                        }
                    } else {
                        actionButtonLabel(
                            icon: isSaved ? "checkmark.circle.fill" : "square.and.arrow.down",
                            label: isSaved ? "Saved" : "Save",
                            color: isSaved ? green : .white.opacity(0.8),
                            bg: isSaved ? green.opacity(0.15) : Color.white.opacity(0.1)
                        )
                    }
                }
                .disabled(isSaved || isSaving)
            }
        }
        .padding(14)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func actionButtonLabel(icon: String, label: String, color: Color, bg: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
            Text(label)
                .font(.system(size: 10, weight: .medium))
        }
        .foregroundStyle(color)
        .frame(width: 54, height: 50)
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

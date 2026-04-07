import SwiftUI

struct ProcessingView: View {
    let project: VideoProject
    let splitDuration: Double

    @StateObject private var viewModel = ProcessingViewModel()
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple  = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue    = Color(red: 0.20, green: 0.50, blue: 1.0)

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Overall progress header
                overallHeader
                    .padding(.top, 20)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 20)

                Divider().background(Color.white.opacity(0.08))

                // Per-chunk list
                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.chunkStates) { chunk in
                            ChunkProgressRow(chunk: chunk, purple: purple, blue: blue)
                                .background(.ultraThinMaterial)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14)
                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                )
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 8)
                }

                // Cancel
                Button(role: .destructive) {
                    viewModel.cancel()
                    dismiss()
                } label: {
                    Text("Cancel Processing")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.white.opacity(0.07))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal, 48)
                .padding(.vertical, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .navigationDestination(isPresented: $viewModel.processingComplete) {
            ResultsView(chunks: viewModel.results)
        }
        .alert("Processing Error", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil; dismiss() } }
        )) {
            Button("OK") { dismiss() }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            // Record one processing toward the daily trial limit
            storeManager.recordProcessingUsed()

            var settings = ConversionSettings.default
            settings.addWatermark = false   // No watermark in trial or premium
            settings.chunkDuration = splitDuration
            viewModel.startProcessing(project: project, settings: settings)
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Overall Header

    private var overallHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Processing…")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    Text(headerSubtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Text("\(Int(viewModel.overallProgress * 100))%")
                    .font(.system(size: 28, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
            }

            // Overall progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: geo.size.width * viewModel.overallProgress, height: 6)
                        .animation(.easeInOut(duration: 0.4), value: viewModel.overallProgress)
                }
            }
            .frame(height: 6)
        }
    }

    private var headerSubtitle: String {
        let p = viewModel.progress
        guard p.totalChunks > 0 else { return "" }
        if p.currentChunk <= p.totalChunks {
            return "Part \(p.currentChunk) of \(p.totalChunks) · \(Int(p.chunkProgress * 100))% done"
        }
        return "Finishing up…"
    }
}

// MARK: - ChunkProgressRow

private struct ChunkProgressRow: View {
    let chunk: ChunkProgressState
    let purple: Color
    let blue: Color

    var body: some View {
        HStack(spacing: 14) {
            // Thumbnail
            thumbnailView
                .frame(width: 56, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.leading, 16)

            // Info + progress
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Part \(chunk.partNumber)")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)

                    Spacer()

                    statusBadge
                }

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text(chunk.formattedRange)
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                    Text("·")
                    Text(chunk.formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.45))

                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 5)

                        Capsule()
                            .fill(barFill)
                            .frame(width: geo.size.width * chunk.progress, height: 5)
                            .animation(.easeInOut(duration: 0.3), value: chunk.progress)
                    }
                }
                .frame(height: 5)

                // Percentage label
                Text(progressLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(progressLabelColor)
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
        }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = chunk.thumbnail {
            Image(uiImage: thumb)
                .resizable()
                .scaledToFill()
        } else {
            Rectangle()
                .fill(Color.white.opacity(0.07))
                .overlay {
                    Image(systemName: "video.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white.opacity(0.2))
                }
        }
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch chunk.status {
        case .done:
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("Done")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.green)
        case .processing:
            HStack(spacing: 4) {
                Circle()
                    .fill(purple)
                    .frame(width: 6, height: 6)
                    .overlay { Circle().fill(.white.opacity(0.4)).frame(width: 3, height: 3) }
                Text("Processing")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(purple)
        case .pending:
            Text("Pending")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.3))
        }
    }

    private var barFill: LinearGradient {
        switch chunk.status {
        case .done:
            return LinearGradient(colors: [.green, .green.opacity(0.7)], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing)
        }
    }

    private var progressLabel: String {
        switch chunk.status {
        case .done:      return "Complete"
        case .processing: return "\(Int(chunk.progress * 100))%"
        case .pending:   return "Waiting…"
        }
    }

    private var progressLabelColor: Color {
        switch chunk.status {
        case .done:       return .green.opacity(0.8)
        case .processing: return purple
        case .pending:    return .white.opacity(0.25)
        }
    }
}

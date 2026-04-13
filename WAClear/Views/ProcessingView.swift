import SwiftUI
import AVFoundation

struct ProcessingView: View {
    let project: VideoProject
    let splitDuration: Double

    @StateObject private var viewModel = ProcessingViewModel()
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss
    @State private var hasStarted = false
    @State private var confirmed = false
    @State private var excludedChunks: Set<Int> = []
    @State private var chunkThumbnails: [Int: UIImage] = [:]

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple  = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue    = Color(red: 0.20, green: 0.50, blue: 1.0)

    private var allChunkRanges: [(index: Int, start: Double, end: Double)] {
        let total = project.chunkCount(chunkDuration: splitDuration)
        return (0..<total).map { i in
            let start = Double(i) * splitDuration
            let end   = min(start + splitDuration, project.duration)
            return (i, start, end)
        }
    }

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            if confirmed {
                processingContent
            } else {
                reviewContent
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
        .onChange(of: viewModel.processingComplete) { complete in
            if !complete && hasStarted {
                dismiss()
            }
        }
        .task { await loadChunkThumbnails() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Review UI (pre-processing selection)

    private var reviewContent: some View {
        VStack(spacing: 0) {
            reviewHeader
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 16)

            Divider().background(Color.white.opacity(0.08))

            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(allChunkRanges, id: \.index) { chunk in
                        ChunkSelectionRow(
                            index: chunk.index,
                            start: chunk.start,
                            end: chunk.end,
                            thumbnail: chunkThumbnails[chunk.index],
                            isSelected: !excludedChunks.contains(chunk.index),
                            purple: purple,
                            blue: blue
                        ) { selected in
                            if selected {
                                excludedChunks.remove(chunk.index)
                            } else {
                                excludedChunks.insert(chunk.index)
                            }
                        }
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(
                                    excludedChunks.contains(chunk.index)
                                        ? Color.white.opacity(0.04)
                                        : Color.white.opacity(0.08),
                                    lineWidth: 1
                                )
                        )
                        .opacity(excludedChunks.contains(chunk.index) ? 0.45 : 1.0)
                        .animation(.easeInOut(duration: 0.15), value: excludedChunks.contains(chunk.index))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            reviewBottomBar
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(bgColor)
        }
    }

    private var reviewHeader: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Select Parts to Process")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)
                    let selected = allChunkRanges.count - excludedChunks.count
                    Text("\(selected) of \(allChunkRanges.count) parts selected")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Button("Cancel") { dismiss() }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
    }

    private var reviewBottomBar: some View {
        VStack(spacing: 10) {
            let selectedCount = allChunkRanges.count - excludedChunks.count
            let canStart = selectedCount > 0

            Button {
                guard canStart else { return }
                confirmed = true
                beginProcessing()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 17, weight: .semibold))
                    Text(canStart
                         ? "Process \(selectedCount) Part\(selectedCount == 1 ? "" : "s")"
                         : "Select at least one part")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(
                    canStart
                        ? LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing)
                        : LinearGradient(colors: [Color.white.opacity(0.1), Color.white.opacity(0.08)],
                                         startPoint: .leading, endPoint: .trailing)
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(!canStart)

            if allChunkRanges.count > 1 {
                Button {
                    if excludedChunks.isEmpty {
                        excludedChunks = Set(allChunkRanges.map(\.index))
                    } else {
                        excludedChunks = []
                    }
                } label: {
                    Text(excludedChunks.isEmpty ? "Deselect All" : "Select All")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    // MARK: - Processing UI

    private var processingContent: some View {
        VStack(spacing: 0) {
            overallHeader
                .padding(.top, 20)
                .padding(.horizontal, 24)
                .padding(.bottom, 20)

            Divider().background(Color.white.opacity(0.08))

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

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 6)
                    Capsule()
                        .fill(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(0, geo.size.width * viewModel.overallProgress), height: 6)
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

    // MARK: - Helpers

    private func beginProcessing() {
        guard !hasStarted else { return }
        hasStarted = true
        var settings = ConversionSettings.default
        settings.addWatermark = !storeManager.isPremium
        settings.chunkDuration = splitDuration
        viewModel.startProcessing(
            project: project,
            settings: settings,
            excludedChunks: excludedChunks
        )
    }

    private func loadChunkThumbnails() async {
        let asset = AVURLAsset(url: project.sourceURL)
        let gen = AVAssetImageGenerator(asset: asset)
        gen.appliesPreferredTrackTransform = true
        gen.maximumSize = CGSize(width: 160, height: 285)
        gen.requestedTimeToleranceBefore = CMTime(seconds: 2, preferredTimescale: 600)
        gen.requestedTimeToleranceAfter  = CMTime(seconds: 2, preferredTimescale: 600)

        for chunk in allChunkRanges {
            let sampleOffset = min(1.0, (chunk.end - chunk.start) / 2)
            let time = CMTime(seconds: chunk.start + sampleOffset, preferredTimescale: 600)
            if let cgImage = try? await gen.image(at: time).image {
                let img = UIImage(cgImage: cgImage)
                await MainActor.run { chunkThumbnails[chunk.index] = img }
            }
        }
    }
}

// MARK: - ChunkSelectionRow

private struct ChunkSelectionRow: View {
    let index: Int
    let start: Double
    let end: Double
    let thumbnail: UIImage?
    let isSelected: Bool
    let purple: Color
    let blue: Color
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
                .frame(width: 56, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.leading, 16)

            VStack(alignment: .leading, spacing: 6) {
                Text("Part \(index + 1)")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)

                HStack(spacing: 6) {
                    Image(systemName: "clock")
                        .font(.system(size: 10))
                    Text("\(start.mmss) → \(end.mmss)")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                    Text("·")
                    Text((end - start).formattedDuration)
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.45))
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isSelected },
                set: { onToggle($0) }
            ))
            .labelsHidden()
            .tint(purple)
            .padding(.trailing, 16)
        }
        .padding(.vertical, 14)
        .contentShape(Rectangle())
        .onTapGesture { onToggle(!isSelected) }
    }

    @ViewBuilder
    private var thumbnailView: some View {
        if let thumb = thumbnail {
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
}

// MARK: - ChunkProgressRow

private struct ChunkProgressRow: View {
    let chunk: ChunkProgressState
    let purple: Color
    let blue: Color

    var body: some View {
        HStack(spacing: 14) {
            thumbnailView
                .frame(width: 56, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                .padding(.leading, 16)

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

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                            .frame(height: 5)

                        Capsule()
                            .fill(barFill)
                            .frame(width: max(0, geo.size.width * chunk.progress), height: 5)
                            .animation(.easeInOut(duration: 0.3), value: chunk.progress)
                    }
                }
                .frame(height: 5)

                Text(progressLabel)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(progressLabelColor)
            }
            .padding(.vertical, 16)
            .padding(.trailing, 16)
        }
    }

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
        case .done:       return "Complete"
        case .processing: return "\(Int(chunk.progress * 100))%"
        case .pending:    return "Waiting…"
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

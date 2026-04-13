import SwiftUI
import PhotosUI

struct HomeView: View {
    @StateObject private var viewModel = HomeViewModel()
    @EnvironmentObject private var storeManager: StoreManager
    @State private var showSubscription = false

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue   = Color(red: 0.20, green: 0.50, blue: 1.0)

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 28) {
                        headerSection

                        if let preview = viewModel.videoPreview {
                            videoReadyCard(preview: preview)
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))

                            actionArea
                                .padding(.horizontal, 24)
                                .transition(.move(edge: .bottom).combined(with: .opacity))
                        } else {
                            PhotosPicker(
                                selection: $viewModel.selectedItem,
                                matching: .videos,
                                photoLibrary: .shared()
                            ) {
                                selectButtonLabel
                            }
                            .onChange(of: viewModel.selectedItem) { item in
                                Task { await viewModel.handlePickedItem(item) }
                            }
                            .padding(.horizontal, 24)
                            .transition(.opacity)
                        }

                        if !storeManager.isPremium {
                            upgradeBanner
                        }

                        Spacer(minLength: 40)
                    }
                    .padding(.top, viewModel.videoPreview != nil ? 20 : 60)
                    .animation(.spring(response: 0.45, dampingFraction: 0.8), value: viewModel.videoPreview != nil)
                }
            }
            .navigationDestination(isPresented: Binding(
                get: { viewModel.navigateTo != nil },
                set: { if !$0 { viewModel.navigateTo = nil } }
            )) {
                if let destination = viewModel.navigateTo {
                    switch destination {
                    case .processing(let project, let splitDuration):
                        ProcessingView(project: project, splitDuration: splitDuration)
                    }
                }
            }
            .sheet(isPresented: $viewModel.showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .onAppear { Task { await storeManager.checkCurrentEntitlements() } }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { viewModel.showSettings = true } label: {
                        Image(systemName: "gear")
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .alert("Error", isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )) {
                Button("OK") { viewModel.clearError() }
            } message: {
                Text(viewModel.errorMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var headerSection: some View {
        Group {
            if viewModel.videoPreview != nil {
                // Compact wordmark when video is loaded
                Text("WAClear")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
            } else {
                // Full hero on empty state
                VStack(spacing: 16) {
                    Text("WAClear")
                        .font(.system(size: 36, weight: .black))
                        .foregroundStyle(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))

                    Text("Crystal Clear\nWhatsApp Status")
                        .font(.system(size: 28, weight: .bold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)

                    Text("Convert any video into WhatsApp-ready status clips at optimal quality — no blur, no quality loss.")
                        .font(.system(size: 15))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.6))
                        .padding(.horizontal, 32)

                    marketingBadges
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Marketing Badges

    private var marketingBadges: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                marketingBadge(icon: "sparkles", label: "HD Quality", color: purple)
                marketingBadge(icon: "logo.whatsapp", label: "WhatsApp Optimized", color: Color(red: 0.07, green: 0.63, blue: 0.22))
            }
            HStack(spacing: 8) {
                marketingBadge(icon: "scissors", label: "Auto-Split 30s", color: blue)
                marketingBadge(icon: "lock.open.fill", label: "No Blur", color: Color(red: 0.95, green: 0.65, blue: 0.05))
            }
        }
    }

    private func marketingBadge(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(color.opacity(0.25), lineWidth: 1))
    }

    // MARK: - Select Button

    private var selectButtonLabel: some View {
        HStack(spacing: 12) {
            Image(systemName: "video.badge.plus")
                .font(.system(size: 20, weight: .semibold))
            Text("Select Video")
                .font(.system(size: 17, weight: .bold))
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 60)
        .background(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
    }

    // MARK: - Action Area (Start / Analyzing)

    @ViewBuilder
    private var actionArea: some View {
        if viewModel.isPreparingFile {
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analyzing video…")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                        Text("Almost ready")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.45))
                    }

                    Spacer()

                    Button("Cancel") {
                        viewModel.cancelLoading()
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .clipShape(Capsule())
                }
                .padding(.horizontal, 18)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
                indeterminateBar
            }
        } else {
            let isLoadingFile = viewModel.isLoadingFile

            Button { viewModel.startProcessing() } label: {
                HStack(spacing: 10) {
                    if isLoadingFile {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .tint(.white)
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 17, weight: .semibold))
                    }
                    Text(isLoadingFile ? "Loading…" : "Start Processing")
                        .font(.system(size: 17, weight: .bold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            }
        }
    }

    private var indeterminateBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(Color.white.opacity(0.08)).frame(height: 4)
                ShimmerBar(totalWidth: geo.size.width)
            }
        }
        .frame(height: 4)
    }

    // MARK: - Video Ready Card

    private func videoReadyCard(preview: VideoPreviewInfo) -> some View {
        VStack(spacing: 0) {
            // Thumbnail or placeholder header
            thumbnailHeader(preview: preview)

            if preview.isKnown {
                Divider().background(Color.white.opacity(0.08))

                // Split duration picker
                splitPicker
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.08))

                let chunks = preview.chunkCount(splitDuration: viewModel.splitDuration)
                HStack(spacing: 0) {
                    statCell(value: preview.duration.formattedDuration, label: "Duration", icon: "clock")
                    dividerLine
                    statCell(
                        value: "\(chunks)",
                        label: chunks == 1 ? "Part" : "Parts",
                        icon: "square.stack"
                    )
                    dividerLine
                    statCell(
                        value: preview.isPortrait ? "Portrait" : "Landscape",
                        label: "Orientation",
                        icon: preview.isPortrait ? "iphone" : "iphone.landscape"
                    )
                }
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.2), value: viewModel.splitDuration)
            }

            Divider().background(Color.white.opacity(0.08))

            PhotosPicker(selection: $viewModel.selectedItem, matching: .videos, photoLibrary: .shared()) {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Change Video")
                        .font(.system(size: 13, weight: .semibold))
                }
                .foregroundStyle(.white.opacity(0.5))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
            }
            .onChange(of: viewModel.selectedItem) { item in
                Task { await viewModel.handlePickedItem(item) }
            }
        }
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
        .overlay(
            RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
    }

    @ViewBuilder
    private func thumbnailHeader(preview: VideoPreviewInfo) -> some View {
        ZStack(alignment: .bottom) {
            // Thumbnail image or gradient placeholder
            if let thumb = viewModel.thumbnail {
                Image(uiImage: thumb)
                    .resizable()
                    .scaledToFill()
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .clipped()
                    .transition(.opacity.animation(.easeIn(duration: 0.3)))
            } else {
                // Animated placeholder until thumbnail loads
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [purple.opacity(0.3), blue.opacity(0.3)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 160)
                    .overlay {
                        Image(systemName: "video.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.25))
                    }
            }

            // Gradient scrim so text is readable
            LinearGradient(
                colors: [.clear, .black.opacity(0.75)],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: 90)

            // Title + dismiss button overlaid on thumbnail
            HStack(alignment: .bottom, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Video selected")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(.white)
                    if preview.isKnown {
                        let c = preview.chunkCount(splitDuration: viewModel.splitDuration)
                        Text("Will be split into \(c) part\(c == 1 ? "" : "s")")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.7))
                            .animation(.easeInOut(duration: 0.2), value: viewModel.splitDuration)
                    }
                }
                Spacer()
                Button { viewModel.clearSelectedVideo() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.8))
                        .shadow(color: .black.opacity(0.5), radius: 4)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Split Duration Picker

    private var splitPicker: some View {
        HStack(spacing: 8) {
            Text("Split every")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white.opacity(0.6))

            Spacer()

            HStack(spacing: 4) {
                ForEach([15.0, 30.0, 60.0], id: \.self) { duration in
                    let selected = viewModel.splitDuration == duration
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            viewModel.splitDuration = duration
                        }
                    } label: {
                        Text("\(Int(duration))s")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(selected ? .white : .white.opacity(0.45))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 7)
                            .background(
                                selected
                                    ? LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing)
                                    : LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.08)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }

    private func statCell(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundStyle(purple)
            Text(value)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.white)
            Text(label)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity)
    }

    private var dividerLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.08))
            .frame(width: 1, height: 44)
    }

    // MARK: - Upgrade Banner (shown to non-premium users)

    private var upgradeBanner: some View {
        Button { showSubscription = true } label: {
            HStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(purple)
                VStack(alignment: .leading, spacing: 2) {
                    Text(storeManager.isEligibleForTrial ? "Try Premium Free for 3 Days" : "Go Premium")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                    Text(storeManager.isEligibleForTrial
                         ? "No watermark · Unlimited conversions"
                         : "Remove watermark · Unlimited conversions")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(
                        LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 1
                    )
            )
            .padding(.horizontal, 24)
        }
    }
}

// MARK: - ShimmerBar

/// Sliding highlight bar for the indeterminate loading indicator.
private struct ShimmerBar: View {
    let totalWidth: CGFloat
    @State private var offset: CGFloat = -80

    var body: some View {
        Capsule()
            .fill(
                LinearGradient(
                    colors: [.clear, .white.opacity(0.5), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(width: 80, height: 4)
            .offset(x: offset)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    offset = totalWidth
                }
            }
    }
}

#Preview {
    HomeView()
        .environmentObject(StoreManager())
}

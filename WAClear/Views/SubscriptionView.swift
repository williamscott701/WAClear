import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)

    private let features: [(String, String)] = [
        ("infinity", "Unlimited conversions every day"),
        ("video.badge.checkmark", "No daily processing cap"),
        ("arrow.up.circle", "Crystal-clear 960×1704 quality"),
        ("waveform", "AAC 128kbps audio"),
        ("bolt.fill", "Fast, on-device processing"),
        ("lock.open.fill", "Keep access forever while subscribed")
    ]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Close button
                HStack {
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)

                ScrollView {
                    VStack(spacing: 28) {
                        // Hero
                        heroSection

                        // Feature list
                        featureList

                        // Price & purchase
                        purchaseSection

                        // Restore link
                        Button("Restore Purchase") {
                            Task { await storeManager.restorePurchases() }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 32)
                    }
                    .padding(.top, 16)
                }
            }
        }
        .alert("Error", isPresented: Binding(
            get: { storeManager.purchaseError != nil },
            set: { _ in storeManager.purchaseError = nil }
        )) {
            Button("OK") { storeManager.purchaseError = nil }
        } message: {
            Text(storeManager.purchaseError ?? "")
        }
        .task { await storeManager.loadProducts() }
        .preferredColorScheme(.dark)
    }

    // MARK: - Hero

    private var heroSection: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(red: 0.58, green: 0.20, blue: 1.0), Color(red: 0.85, green: 0.25, blue: 0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            Text(storeManager.trialStatus == .expired ? "Trial Ended" : "Go Premium")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(.white)

            Text(storeManager.trialStatus == .expired
                 ? "Your 3-day free trial has ended.\nSubscribe to keep converting videos."
                 : "Unlimited daily conversions,\nno restrictions — ever.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 14) {
            ForEach(features, id: \.0) { (icon, text) in
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(red: 0.58, green: 0.20, blue: 1.0))
                        .frame(width: 32)
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    Spacer()
                }
            }
        }
        .padding(.horizontal, 36)
    }

    // MARK: - Purchase Section

    private var purchaseSection: some View {
        VStack(spacing: 14) {
            // Price card
            VStack(spacing: 4) {
                if let product = storeManager.product {
                    Text(product.displayPrice)
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                    Text("per month • cancel anytime")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                } else {
                    Text("₹99")
                        .font(.system(size: 40, weight: .black))
                        .foregroundStyle(.white)
                    Text("per month • cancel anytime")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            .padding(.horizontal, 24)

            GradientButton(
                storeManager.isLoading ? "Processing…" : "Subscribe Now",
                systemImage: storeManager.isLoading ? nil : "crown.fill"
            ) {
                await storeManager.purchase()
            }
            .disabled(storeManager.isLoading)
            .padding(.horizontal, 24)
        }
    }
}

#Preview {
    SubscriptionView()
        .environmentObject(StoreManager())
}

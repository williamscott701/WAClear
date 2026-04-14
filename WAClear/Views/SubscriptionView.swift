import SwiftUI
import StoreKit

struct SubscriptionView: View {
    /// Pass false when presenting as a hard paywall (no way to close without subscribing).
    /// Pass true when opened from Settings so the user can navigate back.
    var allowDismiss: Bool = true

    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlan: SubscriptionPlan = .yearly

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple  = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue    = Color(red: 0.20, green: 0.50, blue: 1.0)
    private let gold    = Color(red: 0.98, green: 0.75, blue: 0.10)

    private let features: [(String, String)] = [
        ("sparkles",             "Crystal clear videos on WhatsApp Status"),
        ("video.badge.checkmark","No watermark — clean videos every time"),
        ("scissors",             "Auto-split into WhatsApp Status clips"),
        ("bolt.fill",            "Unlimited conversions, on-device & private"),
        ("lock.shield.fill",     "100% private — nothing leaves your phone")
    ]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: close button only if allowed
                if allowDismiss {
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
                } else {
                    Color.clear.frame(height: 52)
                }

                ScrollView {
                    VStack(spacing: 24) {
                        heroSection
                        featureList
                        planPicker
                        ctaSection
                        footerLinks
                    }
                    .padding(.top, 8)
                    .padding(.bottom, 40)
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
                            colors: [purple, Color(red: 0.85, green: 0.25, blue: 0.60)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 80, height: 80)
                Image(systemName: "crown.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(.white)
            }

            // Trial badge — always visible so users know a free trial is available
            if storeManager.isEligibleForTrial {
                Text("3 DAYS FREE TRIAL")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 5)
                    .background(gold)
                    .clipShape(Capsule())
            }

            Text(storeManager.isEligibleForTrial ? "Try Free for 3 Days" : "Go Premium")
                .font(.system(size: 32, weight: .black))
                .foregroundStyle(.white)

            Text(storeManager.isEligibleForTrial
                 ? "Stop WhatsApp from blurring your videos.\nNo charge for the first 3 days."
                 : "Stop WhatsApp from blurring your videos.\nCancel anytime.")
                .font(.system(size: 15))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.6))
        }
    }

    // MARK: - Features

    private var featureList: some View {
        VStack(spacing: 12) {
            ForEach(features, id: \.0) { icon, text in
                HStack(spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(purple)
                        .frame(width: 28)
                    Text(text)
                        .font(.system(size: 15))
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.green.opacity(0.8))
                }
            }
        }
        .padding(.horizontal, 32)
    }

    // MARK: - Plan Picker

    private var planPicker: some View {
        HStack(spacing: 12) {
            planCard(
                plan: .yearly,
                title: "Yearly",
                price: storeManager.yearlyProduct?.displayPrice ?? "₹499",
                period: "/year",
                badge: "Best Value — Save 57%",
                badgeColor: gold
            )
            planCard(
                plan: .monthly,
                title: "Monthly",
                price: storeManager.monthlyProduct?.displayPrice ?? "₹99",
                period: "/month",
                badge: nil,
                badgeColor: nil
            )
        }
        .padding(.horizontal, 24)
    }

    private func planCard(
        plan: SubscriptionPlan,
        title: String,
        price: String,
        period: String,
        badge: String?,
        badgeColor: Color?
    ) -> some View {
        let isSelected = selectedPlan == plan
        return Button { withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) { selectedPlan = plan } } label: {
            VStack(spacing: 8) {
                // Badge slot — always reserve space so cards stay equal height
                if let badge, let color = badgeColor {
                    Text(badge)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(color)
                        .clipShape(Capsule())
                } else {
                    Color.clear.frame(height: 22)
                }

                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.55))

                VStack(spacing: 0) {
                    Text(price)
                        .font(.system(size: 22, weight: .black))
                        .foregroundStyle(isSelected ? .white : .white.opacity(0.55))
                    Text(period)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(isSelected ? .white.opacity(0.7) : .white.opacity(0.35))
                }

                if plan == .yearly {
                    Text("~₹42/month")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(isSelected ? gold.opacity(0.9) : .white.opacity(0.3))
                } else {
                    Color.clear.frame(height: 15)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .background(
                isSelected
                    ? LinearGradient(colors: [purple.opacity(0.35), blue.opacity(0.25)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
                    : LinearGradient(colors: [Color.white.opacity(0.06), Color.white.opacity(0.04)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(RoundedRectangle(cornerRadius: Constants.UI.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Constants.UI.cornerRadius)
                    .stroke(
                        isSelected
                            ? LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [Color.white.opacity(0.12), Color.white.opacity(0.12)],
                                             startPoint: .leading, endPoint: .trailing),
                        lineWidth: isSelected ? 2 : 1
                    )
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA

    private var ctaSection: some View {
        VStack(spacing: 12) {
            GradientButton(
                storeManager.isLoading
                    ? "Processing…"
                    : (storeManager.isEligibleForTrial ? "Start Free Trial" : "Subscribe Now"),
                systemImage: storeManager.isLoading ? nil : "crown.fill"
            ) {
                await storeManager.purchase(plan: selectedPlan)
            }
            .disabled(storeManager.isLoading)
            .padding(.horizontal, 24)

            // Trial / pricing note
            Group {
                if storeManager.isEligibleForTrial {
                    let price = selectedPlan == .yearly
                        ? (storeManager.yearlyProduct?.displayPrice ?? "₹499")
                        : (storeManager.monthlyProduct?.displayPrice ?? "₹99")
                    let period = selectedPlan == .yearly ? "year" : "month"
                    Text("3 days free, then \(price)/\(period). Cancel anytime.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                } else {
                    let price = selectedPlan == .yearly
                        ? (storeManager.yearlyProduct?.displayPrice ?? "₹499")
                        : (storeManager.monthlyProduct?.displayPrice ?? "₹99")
                    let period = selectedPlan == .yearly ? "year" : "month"
                    Text("\(price)/\(period). Cancel anytime.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.4))
                        .multilineTextAlignment(.center)
                }
            }
            .padding(.horizontal, 36)
        }
    }

    // MARK: - Footer

    private var footerLinks: some View {
        HStack(spacing: 24) {
            Button("Restore Purchase") {
                Task { await storeManager.restorePurchases() }
            }
            .font(.system(size: 13))
            .foregroundStyle(.white.opacity(0.35))

            Text("·")
                .foregroundStyle(.white.opacity(0.2))

            Link("Privacy Policy",
                 destination: URL(string: "https://williamscott701.github.io/WAClear/privacy")!)
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.top, 4)
    }
}

#Preview {
    SubscriptionView(allowDismiss: true)
        .environmentObject(StoreManager())
}

import SwiftUI

struct OnboardingView: View {
    @Binding var hasSeenOnboarding: Bool
    @State private var currentPage = 0

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let purple  = Color(red: 0.58, green: 0.20, blue: 1.0)
    private let blue    = Color(red: 0.20, green: 0.50, blue: 1.0)

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            iconBg: Color(red: 0.58, green: 0.20, blue: 1.0),
            title: "Crystal Clear Quality",
            subtitle: "No more blurry status updates",
            description: "WAClear encodes your videos at the exact specifications WhatsApp needs — so your Status looks sharp every time.",
            badge: nil
        ),
        OnboardingPage(
            icon: "logo.whatsapp",
            iconBg: Color(red: 0.07, green: 0.63, blue: 0.22),
            title: "WhatsApp Optimized",
            subtitle: "Built to beat the blur",
            description: "We pre-compress at 720p with H.264 + AAC at the right bitrate. When WhatsApp re-compresses, the result stays HD.",
            badge: "720p · H.264 · AAC"
        ),
        OnboardingPage(
            icon: "scissors",
            iconBg: Color(red: 0.20, green: 0.50, blue: 1.0),
            title: "Auto-Split Into 30s Parts",
            subtitle: "Perfect for Status limits",
            description: "WhatsApp Status videos max out at 30 seconds. WAClear automatically splits long videos into share-ready chunks.",
            badge: "≤ 30s per part · ≤ 16 MB"
        ),
        OnboardingPage(
            icon: "square.and.arrow.up.fill",
            iconBg: Color(red: 0.90, green: 0.45, blue: 0.10),
            title: "3 Steps to Perfect Status",
            subtitle: "Select · Configure · Share",
            description: "Pick a video, choose which parts to include, then share directly to WhatsApp. Done in under a minute.",
            badge: nil
        )
    ]

    var body: some View {
        ZStack {
            bgColor.ignoresSafeArea()

            VStack(spacing: 0) {
                TabView(selection: $currentPage) {
                    ForEach(pages.indices, id: \.self) { i in
                        pageView(pages[i])
                            .tag(i)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.35), value: currentPage)

                bottomControls
                    .padding(.horizontal, 32)
                    .padding(.bottom, 52)
                    .padding(.top, 24)
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Page

    private func pageView(_ page: OnboardingPage) -> some View {
        VStack(spacing: 0) {
            Spacer()

            // Icon circle
            ZStack {
                Circle()
                    .fill(page.iconBg.opacity(0.18))
                    .frame(width: 120, height: 120)
                Circle()
                    .fill(page.iconBg.opacity(0.32))
                    .frame(width: 88, height: 88)
                Image(systemName: page.icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .padding(.bottom, 36)

            VStack(spacing: 10) {
                Text(page.title)
                    .font(.system(size: 30, weight: .black))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)

                Text(page.subtitle)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, 20)

            Text(page.description)
                .font(.system(size: 15))
                .foregroundStyle(.white.opacity(0.65))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 36)

            if let badge = page.badge {
                Text(badge)
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundStyle(purple)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 7)
                    .background(purple.opacity(0.12))
                    .clipShape(Capsule())
                    .overlay(Capsule().stroke(purple.opacity(0.3), lineWidth: 1))
                    .padding(.top, 20)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 20) {
            // Page dots
            HStack(spacing: 8) {
                ForEach(pages.indices, id: \.self) { i in
                    Capsule()
                        .fill(i == currentPage
                              ? LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing)
                              : LinearGradient(colors: [Color.white.opacity(0.2), Color.white.opacity(0.2)],
                                               startPoint: .leading, endPoint: .trailing))
                        .frame(width: i == currentPage ? 24 : 8, height: 8)
                        .animation(.spring(response: 0.35, dampingFraction: 0.75), value: currentPage)
                }
            }

            // Action button
            if currentPage < pages.count - 1 {
                Button {
                    withAnimation { currentPage += 1 }
                } label: {
                    HStack(spacing: 8) {
                        Text("Next")
                            .font(.system(size: 17, weight: .bold))
                        Image(systemName: "arrow.right")
                            .font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            } else {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Get Started")
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(LinearGradient(colors: [purple, blue], startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }

            // Skip link on early pages
            if currentPage < pages.count - 1 {
                Button {
                    hasSeenOnboarding = true
                } label: {
                    Text("Skip")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white.opacity(0.35))
                }
            }
        }
    }
}

// MARK: - Page Model

private struct OnboardingPage {
    let icon: String
    let iconBg: Color
    let title: String
    let subtitle: String
    let description: String
    let badge: String?
}

#Preview {
    OnboardingView(hasSeenOnboarding: .constant(false))
}

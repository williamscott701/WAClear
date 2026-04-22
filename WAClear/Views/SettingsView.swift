import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    // Persisted developer-mode and bypass flags — work in any build type
    @AppStorage("devModeUnlocked")    private var devModeUnlocked    = false
    @AppStorage("debugBypassPaywall") private var debugBypassPaywall = false

    private let bgColor      = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let appVersion   = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber  = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    @State private var versionTapCount = 0
    @State private var showDevUnlockedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                List {
                    subscriptionSection
                    aboutSection
                    if devModeUnlocked { developerSection }
                }
                .scrollContentBackground(.hidden)

                if showDevUnlockedToast {
                    VStack {
                        Spacer()
                        Text("Developer mode unlocked")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(Color.orange.opacity(0.9))
                            .clipShape(Capsule())
                            .padding(.bottom, 32)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // MARK: - Sections

    private var subscriptionSection: some View {
        Section {
            if storeManager.isPremium {
                HStack {
                    Image(systemName: "crown.fill")
                        .foregroundStyle(Color(red: 0.58, green: 0.20, blue: 1.0))
                    Text("Premium Active")
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            } else {
                NavigationLink {
                    SubscriptionView(allowDismiss: true)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "crown")
                            .foregroundStyle(Color(red: 0.58, green: 0.20, blue: 1.0))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Go Premium")
                                .foregroundStyle(.white)
                            Text("Post WhatsApp Status without the blur")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.5))
                            if storeManager.isEligibleForTrial {
                                Text("3 days free — no charge until trial ends")
                                    .font(.caption)
                                    .foregroundStyle(Color(red: 0.98, green: 0.75, blue: 0.10))
                            }
                        }
                    }
                }
            }

            Button {
                Task { await storeManager.restorePurchases() }
            } label: {
                HStack {
                    Image(systemName: "arrow.clockwise")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Restore Purchases")
                        .foregroundStyle(.white)
                }
            }
        } header: {
            Text("Subscription")
                .foregroundStyle(.white.opacity(0.5))
        }
        .listRowBackground(Color.white.opacity(0.07))
    }

    private var aboutSection: some View {
        Section {
            // Tap version 7 times to unlock developer section
            HStack {
                Text("Version")
                    .foregroundStyle(.white)
                Spacer()
                Text("\(appVersion) (\(buildNumber))")
                    .foregroundStyle(.white.opacity(0.5))
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !devModeUnlocked else { return }
                versionTapCount += 1
                if versionTapCount >= 7 {
                    devModeUnlocked = true
                    withAnimation { showDevUnlockedToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        withAnimation { showDevUnlockedToast = false }
                    }
                }
            }

            Link(destination: URL(string: "mailto:williamscott701@gmail.com")!) {
                HStack {
                    Image(systemName: "envelope")
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Contact Support")
                        .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        } header: {
            Text("About")
                .foregroundStyle(.white.opacity(0.5))
        }
        .listRowBackground(Color.white.opacity(0.07))
    }

    private var developerSection: some View {
        Section {
            Toggle(isOn: $debugBypassPaywall) {
                HStack {
                    Image(systemName: "ladybug.fill")
                        .foregroundStyle(.orange)
                    Text("Bypass Paywall")
                        .foregroundStyle(.white)
                }
            }
            .tint(.orange)

            Button(role: .destructive) {
                devModeUnlocked    = false
                debugBypassPaywall = false
                versionTapCount    = 0
            } label: {
                HStack {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.red.opacity(0.8))
                    Text("Lock Developer Mode")
                        .foregroundStyle(.red.opacity(0.8))
                }
            }
        } header: {
            Text("Developer")
                .foregroundStyle(.white.opacity(0.5))
        }
        .listRowBackground(Color.white.opacity(0.07))
    }
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
}

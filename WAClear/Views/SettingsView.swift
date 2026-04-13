import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    private let bgColor = Color(red: 0.04, green: 0.04, blue: 0.06)
    private let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    private let buildNumber = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"

    var body: some View {
        NavigationStack {
            ZStack {
                bgColor.ignoresSafeArea()

                List {
                    // Subscription section
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
                                        if storeManager.isEligibleForTrial {
                                            Text("3 days free trial — then from ₹99/month")
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

                    // About section
                    Section {
                        HStack {
                            Text("Version")
                                .foregroundStyle(.white)
                            Spacer()
                            Text("\(appVersion) (\(buildNumber))")
                                .foregroundStyle(.white.opacity(0.5))
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
                .scrollContentBackground(.hidden)
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
}

#Preview {
    SettingsView()
        .environmentObject(StoreManager())
}

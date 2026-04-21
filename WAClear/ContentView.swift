import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @EnvironmentObject private var storeManager: StoreManager
    #if DEBUG
    @AppStorage("debugBypassPaywall") private var debugBypassPaywall = false
    #endif

    var body: some View {
        HomeView()
            // 1. First-launch onboarding carousel
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            )) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
            // 2. Hard paywall — shown after onboarding, cannot be dismissed without subscribing
            .fullScreenCover(isPresented: Binding(
                get: {
                    #if DEBUG
                    return hasSeenOnboarding && !storeManager.isPremium && !debugBypassPaywall
                    #else
                    return hasSeenOnboarding && !storeManager.isPremium
                    #endif
                },
                set: { _ in }
            )) {
                SubscriptionView(allowDismiss: false)
                    .environmentObject(storeManager)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
}

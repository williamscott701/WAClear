import SwiftUI

struct ContentView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        HomeView()
            .fullScreenCover(isPresented: Binding(
                get: { !hasSeenOnboarding },
                set: { if !$0 { hasSeenOnboarding = true } }
            )) {
                OnboardingView(hasSeenOnboarding: $hasSeenOnboarding)
            }
    }
}

#Preview {
    ContentView()
        .environmentObject(StoreManager())
}

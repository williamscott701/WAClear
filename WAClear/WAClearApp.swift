import SwiftUI

@main
struct WAClearApp: App {
    @StateObject private var storeManager = StoreManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storeManager)
                .task {
                    await storeManager.checkCurrentEntitlements()
                }
        }
    }
}

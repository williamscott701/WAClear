import Foundation
import Combine
import StoreKit

// MARK: - StoreManager
//
// Uses StoreKit 2 auto-renewable subscriptions.
// The 3-day free trial is an introductory offer configured in App Store Connect
// (and mirrored in Configuration.storekit for local testing).
// Apple manages trial eligibility, billing dates, and renewals automatically.
//
// HOW TO TEST (no real charges):
//   1. In Xcode: Product > Scheme > Edit Scheme > Run > Options
//      Set "StoreKit Configuration" to Configuration.storekit
//   2. Run on simulator — all purchases are simulated locally.
//   3. Tap "Start Free Trial" or "Subscribe Now" to trigger the sandbox sheet.
//   4. Use Debug > StoreKit > Manage Transactions to inspect, refund, or expire subs.
//   5. To test Restore: purchase, delete the app, reinstall, tap "Restore Purchases".

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var isPremium = false
    @Published private(set) var isEligibleForTrial = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published var purchaseError: String?

    /// Every user can always process videos. Non-premium users receive a watermark.
    var canProcess: Bool { true }

    private var transactionListenerTask: Task<Void, Never>?

    init() {
        transactionListenerTask = listenForTransactions()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Constants.StoreKit.monthlyProductID])
            product = products.first
            await updateTrialEligibility()
        } catch {
            purchaseError = "Could not load products: \(error.localizedDescription)"
        }
    }

    private func updateTrialEligibility() async {
        guard let sub = product?.subscription else {
            isEligibleForTrial = false
            return
        }
        isEligibleForTrial = await sub.isEligibleForIntroOffer
    }

    // MARK: - Purchase

    func purchase() async {
        guard let product else {
            purchaseError = "Product not available. Please try again."
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    isPremium = true
                    await transaction.finish()
                } else {
                    purchaseError = "Purchase verification failed."
                }
            case .userCancelled:
                break
            case .pending:
                purchaseError = "Your purchase is pending approval. Check your payment method in Settings."
            @unknown default:
                break
            }
        } catch {
            purchaseError = "Purchase failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Restore

    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await AppStore.sync()
            await checkCurrentEntitlements()
        } catch {
            purchaseError = "Restore failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Entitlement Check

    func checkCurrentEntitlements() async {
        var foundPremium = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == Constants.StoreKit.monthlyProductID,
               transaction.revocationDate == nil {
                foundPremium = true
                await transaction.finish()
            }
        }
        isPremium = foundPremium
        await updateTrialEligibility()
    }

    // MARK: - Transaction Listener

    @discardableResult
    private func listenForTransactions() -> Task<Void, Never> {
        Task(priority: .background) {
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await self.checkCurrentEntitlements()
                    await transaction.finish()
                }
            }
        }
    }
}

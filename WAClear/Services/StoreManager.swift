import Foundation
import Combine
import StoreKit

// MARK: - SubscriptionPlan

enum SubscriptionPlan: Equatable {
    case monthly
    case yearly
}

// MARK: - StoreManager
//
// Uses StoreKit 2 auto-renewable subscriptions.
// Two plans: monthly (₹99/mo) and yearly (₹499/yr — ~57% savings).
// Both plans include a 3-day free trial introductory offer.
// Apple manages trial eligibility, billing dates, and renewals automatically.
//
// HOW TO TEST (no real charges):
//   1. In Xcode: Product > Scheme > Edit Scheme > Run > Options
//      Set "StoreKit Configuration" to Configuration.storekit
//   2. Run on simulator — all purchases are simulated locally.
//   3. Tap "Start Free Trial" to trigger the sandbox sheet.
//   4. Use Debug > StoreKit > Manage Transactions to inspect, refund, or expire subs.
//   5. To test Restore: purchase, delete the app, reinstall, tap "Restore Purchases".

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var isPremium = false
    @Published private(set) var isEligibleForTrial = false
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var isLoading = false
    @Published var purchaseError: String?

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
            let products = try await Product.products(for: Constants.StoreKit.allProductIDs)
            for p in products {
                if p.id == Constants.StoreKit.yearlyProductID  { yearlyProduct  = p }
                if p.id == Constants.StoreKit.monthlyProductID { monthlyProduct = p }
            }
            await updateTrialEligibility()
        } catch {
            purchaseError = "Could not load products: \(error.localizedDescription)"
        }
    }

    private func updateTrialEligibility() async {
        // Check yearly first (the default/recommended plan), fall back to monthly
        if let yearlySub = yearlyProduct?.subscription {
            isEligibleForTrial = await yearlySub.isEligibleForIntroOffer
        } else if let monthlySub = monthlyProduct?.subscription {
            isEligibleForTrial = await monthlySub.isEligibleForIntroOffer
        } else {
            isEligibleForTrial = false
        }
    }

    // MARK: - Purchase

    func purchase(plan: SubscriptionPlan) async {
        let product = plan == .yearly ? yearlyProduct : monthlyProduct
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
               Constants.StoreKit.allProductIDs.contains(transaction.productID),
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

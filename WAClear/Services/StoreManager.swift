import Foundation
import Combine
import StoreKit

// MARK: - Trial Status

enum TrialStatus: Equatable {
    /// Trial is active — days left in the trial period + processings left today.
    case active(daysRemaining: Int, processingsRemainingToday: Int)
    /// Trial is active but today's processing limit has been hit.
    case dailyLimitReached(daysRemaining: Int)
    /// The 3-day trial has expired and the user is not premium.
    case expired
    /// Active subscription.
    case premium

    var canProcess: Bool {
        switch self {
        case .active:   return true
        case .premium:  return true
        case .dailyLimitReached, .expired: return false
        }
    }

    var isTrialActive: Bool {
        if case .active = self { return true }
        if case .dailyLimitReached = self { return true }
        return false
    }
}

// MARK: - StoreManager

@MainActor
final class StoreManager: ObservableObject {
    @Published private(set) var isPremium = false
    @Published private(set) var product: Product?
    @Published private(set) var isLoading = false
    @Published private(set) var trialStatus: TrialStatus = .active(daysRemaining: Constants.Trial.durationDays,
                                                                    processingsRemainingToday: Constants.Trial.dailyProcessingLimit)
    @Published var purchaseError: String?

    var canProcess: Bool { trialStatus.canProcess }

    private var transactionListenerTask: Task<Void, Never>?

    // MARK: - UserDefaults keys

    private enum UDKey {
        static let firstLaunchDate  = "WAClear.firstLaunchDate"
        static let dailyUsageDate   = "WAClear.dailyUsageDate"
        static let dailyUsageCount  = "WAClear.dailyUsageCount"
    }

    init() {
        transactionListenerTask = listenForTransactions()
        ensureFirstLaunchDateSet()
        refreshTrialStatus()
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // MARK: - Trial

    /// Call this each time the app becomes active so the status reflects the current day/time.
    func refreshTrialStatus() {
        trialStatus = computeTrialStatus()
    }

    /// Call once when a processing job actually starts (not before).
    func recordProcessingUsed() {
        guard !isPremium else { return }
        let today = Calendar.current.startOfDay(for: Date())
        let storedDate = UserDefaults.standard.object(forKey: UDKey.dailyUsageDate) as? Date

        var count = 0
        if let storedDate, Calendar.current.isDate(storedDate, inSameDayAs: today) {
            count = UserDefaults.standard.integer(forKey: UDKey.dailyUsageCount)
        }
        count += 1
        UserDefaults.standard.set(today,  forKey: UDKey.dailyUsageDate)
        UserDefaults.standard.set(count,  forKey: UDKey.dailyUsageCount)
        refreshTrialStatus()
    }

    // MARK: - Private trial helpers

    private func computeTrialStatus() -> TrialStatus {
        guard !isPremium else { return .premium }

        let now = Date()
        let firstLaunch = storedFirstLaunchDate
        let daysSinceLaunch = Calendar.current.dateComponents([.day], from: firstLaunch, to: now).day ?? 0
        let daysRemaining = max(0, Constants.Trial.durationDays - daysSinceLaunch)

        guard daysRemaining > 0 else { return .expired }

        let dailyUsed      = dailyUsageCount
        let dailyRemaining = max(0, Constants.Trial.dailyProcessingLimit - dailyUsed)

        if dailyRemaining == 0 {
            return .dailyLimitReached(daysRemaining: daysRemaining)
        }
        return .active(daysRemaining: daysRemaining, processingsRemainingToday: dailyRemaining)
    }

    private var dailyUsageCount: Int {
        let today = Calendar.current.startOfDay(for: Date())
        guard let storedDate = UserDefaults.standard.object(forKey: UDKey.dailyUsageDate) as? Date,
              Calendar.current.isDate(storedDate, inSameDayAs: today)
        else { return 0 }
        return UserDefaults.standard.integer(forKey: UDKey.dailyUsageCount)
    }

    private var storedFirstLaunchDate: Date {
        if let d = UserDefaults.standard.object(forKey: UDKey.firstLaunchDate) as? Date { return d }
        let now = Date()
        UserDefaults.standard.set(now, forKey: UDKey.firstLaunchDate)
        return now
    }

    private func ensureFirstLaunchDateSet() {
        _ = storedFirstLaunchDate   // side-effect: writes if missing
    }

    // MARK: - Product Loading

    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let products = try await Product.products(for: [Constants.StoreKit.monthlyProductID])
            product = products.first
        } catch {
            purchaseError = "Could not load products: \(error.localizedDescription)"
        }
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
                    trialStatus = .premium
                    await transaction.finish()
                } else {
                    purchaseError = "Purchase verification failed."
                }
            case .userCancelled: break
            case .pending:       break
            @unknown default:    break
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
        refreshTrialStatus()
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

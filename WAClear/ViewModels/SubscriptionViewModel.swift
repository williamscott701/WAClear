import Foundation
import Combine
import SwiftUI
import StoreKit

@MainActor
final class SubscriptionViewModel: ObservableObject {
    @Published var isLoading = false

    private let storeManager: StoreManager

    init(storeManager: StoreManager) {
        self.storeManager = storeManager
    }

    var isPremium: Bool { storeManager.isPremium }
    var product: Product? { storeManager.product }
    var priceText: String {
        if let product = storeManager.product {
            return "\(product.displayPrice)/month"
        }
        return "₹99/month"
    }
    var errorMessage: String? { storeManager.purchaseError }

    func purchase() async {
        await storeManager.purchase()
    }

    func restore() async {
        await storeManager.restorePurchases()
    }

    func loadProducts() async {
        await storeManager.loadProducts()
    }
}

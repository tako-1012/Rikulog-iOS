import Foundation
import Combine
import StoreKit
import SwiftUI

@MainActor
final class StoreKitManager: ObservableObject {
    static let shared = StoreKitManager()

    @Published var isLoading: Bool = true
    @Published var isPremium: Bool = false
    @Published var products: [Product] = []
    @Published var lifetimeProduct: Product? = nil
    @Published var errorMessage: String? = nil

    private let productIDs: [String] = ["rikulog_premium_lifetime"]
    private var transactionListenerTask: Task<Void, Never>? = nil
    
    // UserDefaults キー
    private let premiumCacheKey = "StoreKitManager_isPremium_Cache"

    private init(skipSetup: Bool = false) {
        // 起動時: キャッシュから isPremium を復元（UX改善）
        let cachedPremium = UserDefaults.standard.bool(forKey: premiumCacheKey)
        self.isPremium = cachedPremium
        
        if !skipSetup {
            // 1. 初期化（同期的に完了）
            Task.detached(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                await self.loadProducts()
                await self.updateCustomerProductStatus()
                await MainActor.run {
                    self.isLoading = false
                }
            }
            // 2. トランザクションリスナーは別途非同期で起動（ブロックしない）
            transactionListenerTask = Task.detached(priority: .background) { [weak self] in
                guard let self else { return }
                await self.listenForTransactions()
            }
        }
    }

    deinit {
        transactionListenerTask?.cancel()
    }

    // Preview helper: returns an instance that does not start background tasks
    static func preview() -> StoreKitManager {
        let mgr = StoreKitManager(skipSetup: true)
        mgr.isLoading = false
        mgr.isPremium = false
        mgr.products = []
        mgr.lifetimeProduct = nil
        mgr.errorMessage = nil
        return mgr
    }

    private func setup() async {
        await loadProducts()
        await updateCustomerProductStatus()
        await listenForTransactions()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Set(productIDs))
            await MainActor.run {
                self.products = fetched
                self.lifetimeProduct = fetched.first(where: { $0.id == "rikulog_premium_lifetime" })
            }
        } catch {
            await MainActor.run { self.errorMessage = "製品情報の取得に失敗しました: \(error.localizedDescription)" }
        }
    }

    // MARK: - Purchase
    enum PurchaseError: Error {
        case cancelled
        case pending
        case verificationFailed
        case unknown
    }

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        switch result {
        case let .success(verification):
            let transaction = try checkVerified(verification) as StoreKit.Transaction
            await updateCustomerProductStatus()
            // finish transaction
            await transaction.finish()
            return transaction
        case .userCancelled:
            throw PurchaseError.cancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.unknown
        }
    }

    // MARK: - Restore
    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await updateCustomerProductStatus()
        } catch {
            await MainActor.run { self.errorMessage = "復元に失敗しました: \(error.localizedDescription)" }
        }
    }

    // MARK: - Transactions listener
    private func listenForTransactions() async {
        // listen for transaction updates
        for await verification in StoreKit.Transaction.updates {
            do {
                let transaction = try checkVerified(verification) as StoreKit.Transaction
                await updateCustomerProductStatus()
                await transaction.finish()
            } catch {
                await MainActor.run { self.errorMessage = "トランザクションの検証に失敗しました: \(error)" }
            }
        }
    }

    // MARK: - Entitlement checking
    private func checkVerified<T>(_ result: StoreKit.VerificationResult<T>) throws -> T {
        switch result {
        case .unverified(_, let error):
            throw error
        case .verified(let signed):
            return signed
        }
    }

    func updateCustomerProductStatus() async {
        var hasPremium = false
        #if DEBUG
        print("💎 [StoreKitManager] 課金状態チェック開始")
        #endif

        // Iterate current entitlements and log productIDs
        for await verification in StoreKit.Transaction.currentEntitlements {
            if let transaction = try? checkVerified(verification) {
                #if DEBUG
                print("📦 [StoreKitManager] 有効な履歴検出: \(transaction.productID)")
                #endif
                if productIDs.contains(transaction.productID) {
                    hasPremium = true
                }
            }
        }

        #if DEBUG
        print("🏁 [StoreKitManager] 最終判定: \(hasPremium)")
        #endif

        await MainActor.run {
            self.isPremium = hasPremium
            // キャッシュを更新して次の起動時の読み込みを高速化
            UserDefaults.standard.set(hasPremium, forKey: self.premiumCacheKey)
        }
    }
}

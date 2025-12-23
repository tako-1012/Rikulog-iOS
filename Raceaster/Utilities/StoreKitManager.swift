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
    @Published var monthlyProduct: Product? = nil
    @Published var lifetimeProduct: Product? = nil
    @Published var errorMessage: String? = nil

    private let productIDs: [String] = ["rikulog_premium_monthly", "rikulog_premium_lifetime"]
    private var transactionListenerTask: Task<Void, Never>? = nil

    private init(skipSetup: Bool = false) {
        if !skipSetup {
            transactionListenerTask = Task.detached(priority: .background) { [weak self] in
                await self?.setup()
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
        mgr.monthlyProduct = nil
        mgr.lifetimeProduct = nil
        mgr.errorMessage = nil
        return mgr
    }

    private func setup() async {
        // 1. まず商品情報を読み込む
        await loadProducts()

        // 2. 購入状態を更新する
        await updateCustomerProductStatus()

        // 3. ここで「読み込み中」を解除！（これでグルグルが止まります）
        await MainActor.run { self.isLoading = false }

        // 4. 監視処理は終わらないので、最後に実行（または別タスクにする）
        //    これより下にコードを書くと実行されないので注意
        await listenForTransactions()
    }

    func loadProducts() async {
        do {
            let fetched = try await Product.products(for: Set(productIDs))
            await MainActor.run {
                self.products = fetched
                self.monthlyProduct = fetched.first(where: { $0.id == "rikulog_premium_monthly" })
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

        await MainActor.run { self.isPremium = hasPremium }
    }
}

import Foundation
import StoreKit
import Combine

/// App内課金を管理するクラス
@MainActor
final class StoreManager: ObservableObject {
    
    // MARK: - 商品ID（プレースホルダー）
    private enum ProductID {
        static let monthlyPremium = "com.kotaro.racemaster.monthly_premium"
        static let lifetimePremium = "com.kotaro.racemaster.lifetime_premium"
    }
    
    // MARK: - Published Properties
    @Published private(set) var products: [Product] = []
    @Published private(set) var purchasedProductIDs: Set<String> = []
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // NOTE: Production: start as non-premium. Remove any debug-forced flags.
    @Published var isPremium = false
    
    // MARK: - Singleton
    static let shared = StoreManager()
    
    private var updateListenerTask: Task<Void, Error>?
    
    private init() {
        // トランザクション監視開始
        updateListenerTask = listenForTransactions()
        
        Task {
            await loadProducts()
            await updatePurchasedProducts()
        }
    }
    
    deinit {
        updateListenerTask?.cancel()
    }
    
    // MARK: - 商品読み込み
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let productIDs = [ProductID.monthlyPremium, ProductID.lifetimePremium]
            let loadedProducts = try await Product.products(for: productIDs)
            
            // 買い切りを先に表示（推奨）
            products = loadedProducts.sorted { product1, product2 in
                if product1.id == ProductID.lifetimePremium {
                    return true
                }
                return false
            }
            
            print("✅ Loaded \(products.count) products")
        } catch {
            print("❌ Failed to load products: \(error)")
            errorMessage = "商品の読み込みに失敗しました"
        }
    }
    
    // MARK: - 購入処理
    func purchase(_ product: Product) async throws -> Transaction? {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try checkVerified(verification)
                
                // トランザクションを完了
                await transaction.finish()
                
                // 購入状態を更新
                await updatePurchasedProducts()
                
                print("✅ Purchase successful: \(product.id)")
                return transaction
                
            case .userCancelled:
                print("ℹ️ User cancelled purchase")
                return nil
                
            case .pending:
                print("ℹ️ Purchase pending")
                errorMessage = "購入が保留中です。承認をお待ちください。"
                return nil
                
            @unknown default:
                print("⚠️ Unknown purchase result")
                return nil
            }
        } catch {
            print("❌ Purchase failed: \(error)")
            errorMessage = "購入に失敗しました"
            throw error
        }
    }
    
    // MARK: - 購入復元
    func restorePurchases() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            try await AppStore.sync()
            await updatePurchasedProducts()
            print("✅ Purchases restored")
        } catch {
            print("❌ Failed to restore purchases: \(error)")
            errorMessage = "購入の復元に失敗しました"
        }
    }
    
    // MARK: - 購入状態の更新
    func updatePurchasedProducts() async {
        var purchasedIDs: Set<String> = []
        
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                
                // サブスクリプションの有効期限チェック
                if let expirationDate = transaction.expirationDate,
                   expirationDate < Date() {
                    // 期限切れ
                    continue
                }
                
                purchasedIDs.insert(transaction.productID)
            } catch {
                print("❌ Failed to verify transaction: \(error)")
            }
        }
        
        purchasedProductIDs = purchasedIDs
        // Update isPremium based on actual purchased IDs
        isPremium = !purchasedIDs.isEmpty
        #if DEBUG
        print("✅ Updated purchased products: \(purchasedIDs)")
        #endif
    }
    
    // MARK: - トランザクション監視
    private func listenForTransactions() -> Task<Void, Error> {
        Task {
            for await result in Transaction.updates {
                do {
                    let transaction = try self.checkVerified(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    print("❌ Transaction verification failed: \(error)")
                }
            }
        }
    }
    
    // MARK: - 検証
    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    // MARK: - Premium判定
    // 既存コードとの互換性のため `isPremiumUser` は残し、`isPremium` を返すようにする
    var isPremiumUser: Bool {
        isPremium
    }
    
    // MARK: - 商品取得
    var monthlyProduct: Product? {
        products.first { $0.id == ProductID.monthlyPremium }
    }
    
    var lifetimeProduct: Product? {
        products.first { $0.id == ProductID.lifetimePremium }
    }
}

// MARK: - Errors
enum StoreError: Error {
    case failedVerification
}

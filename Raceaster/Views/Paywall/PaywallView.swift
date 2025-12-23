import SwiftUI
import StoreKit

struct PaywallView: View {
    @EnvironmentObject var store: StoreKitManager
    @Environment(\.dismiss) private var dismiss
    @State private var isPurchasing = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // ヘッダー
                    headerSection
                    
                    // 機能比較
                    featureComparisonSection
                    
                    // プラン選択
                    if store.isLoading {
                        ProgressView()
                            .padding()
                    } else {
                        planSelectionSection
                    }
                    
                    // 復元ボタン
                    restoreButton
                    
                    // 注意事項
                    disclaimerSection
                }
                .padding()
            }
            .navigationTitle("Premiumにアップグレード")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("閉じる") {
                        dismiss()
                    }
                }
            }
            .alert("購入", isPresented: $showAlert) {
                Button("OK") { }
            } message: {
                Text(alertMessage)
            }
            .task {
                // Ensure products are loaded when the view appears
                await store.loadProducts()
            }
        }
    }
    
    // MARK: - ヘッダー
    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "star.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.yellow)
            
            Text("陸ログ Premium")
                .font(.title.bold())
            
            Text("すべての機能を解放")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.top)
    }
    
    // MARK: - 機能比較
    private var featureComparisonSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Premium機能")
                .font(.headline)
            
            featureRow(icon: "infinity", text: "レース記録無制限", isPremium: true)
            featureRow(icon: "eye.slash", text: "広告なし", isPremium: true)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func featureRow(icon: String, text: String, isPremium: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isPremium ? .blue : .gray)
                .frame(width: 24)
            
            Text(text)
                .font(.subheadline)
            
            Spacer()
            
            if isPremium {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.blue)
            }
        }
    }
    
    // MARK: - プラン選択
    private var planSelectionSection: some View {
        VStack(spacing: 16) {
            // If the user already has premium, show a simple message
            if store.isPremium {
                VStack {
                    Text("すでにプレミアム会員です")
                        .font(.headline)
                        .foregroundColor(.green)
                    Button("閉じる") { dismiss() }
                }

            } else {
                // Lifetime/product card
                if let product = store.lifetimeProduct {
                    PremiumPlanCard(
                        title: "買い切り",
                        subtitle: "一度の購入で永久に使用",
                        price: product.displayPrice,
                        isRecommended: true,
                        isPurchasing: isPurchasing
                    ) {
                        Task { await purchaseProduct(product) }
                    }
                }

                // Monthly product card
                if let product = store.monthlyProduct {
                    PremiumPlanCard(
                        title: "月額プラン",
                        subtitle: "いつでもキャンセル可能",
                        price: "\(product.displayPrice)/月",
                        isRecommended: false,
                        isPurchasing: isPurchasing
                    ) {
                        Task { await purchaseProduct(product) }
                    }
                }
            }
        }
    }
    
    // MARK: - 復元ボタン
    private var restoreButton: some View {
        Button {
            Task {
                isPurchasing = true
                await store.restorePurchases()
                isPurchasing = false
                
                if store.isPremium {
                    alertMessage = "購入を復元しました"
                    showAlert = true
                } else {
                    alertMessage = "復元可能な購入が見つかりませんでした"
                    showAlert = true
                }
            }
        } label: {
            Text("購入を復元")
                .font(.subheadline)
                .foregroundColor(.blue)
        }
        .disabled(isPurchasing)
    }
    
    // MARK: - 注意事項
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("• 買い切りプランは一度の購入で永久に利用できます")
            Text("• 月額プランは自動更新されます")
            Text("• キャンセルはApp Storeの設定から行えます")
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.horizontal)
    }
    
    // MARK: - 購入処理
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let transaction = try await store.purchase(product)
            if transaction != nil {
                alertMessage = "購入が完了しました！"
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
            }
        } catch {
            alertMessage = store.errorMessage ?? (error.localizedDescription)
            showAlert = true
        }
    }
}

// MARK: - Premium Plan Card
struct PremiumPlanCard: View {
    let title: String
    let subtitle: String
    let price: String
    let isRecommended: Bool
    let isPurchasing: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    if isRecommended {
                        Text("おすすめ")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }
                
                Divider()
                
                HStack {
                    Text(price)
                        .font(.title2.bold())
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    if isPurchasing {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRecommended ? Color.blue : Color.gray.opacity(0.3), lineWidth: isRecommended ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(isPurchasing)
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreKitManager.preview())
}

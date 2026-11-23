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
            ZStack {
                // 背景グラデーション
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // ヘッダー
                        headerSection
                        
                        // 機能一覧
                        featuresSection
                        
                        // 購入ボタン
                        if store.isLoading {
                            ProgressView()
                                .padding()
                        } else if store.isPremium {
                            premiumActiveSection
                        } else {
                            purchaseSection
                        }
                        
                        // 復元ボタン
                        restoreButton
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 40)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .symbolRenderingMode(.hierarchical)
                    }
                }
            }
            .alert("paywall.purchase.alert.title", isPresented: $showAlert) {
                Button("common.ok") { }
            } message: {
                Text(alertMessage)
            }
            .task {
                await store.loadProducts()
            }
        }
    }
    
    // MARK: - ヘッダー
    private var headerSection: some View {
        VStack(spacing: 16) {
            // アイコン
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)
                
                Image(systemName: "infinity")
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
            }
            .shadow(color: .blue.opacity(0.3), radius: 20, x: 0, y: 10)
            
            VStack(spacing: 8) {
                Text("Premium Plan")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                
                Text("paywall.header.subtitle")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 20)
    }
    
    // MARK: - 機能一覧
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            featureRow(
                icon: "infinity.circle.fill",
                iconColor: .blue,
                title: "paywall.feature.unlimited.title",
                description: "paywall.feature.unlimited.desc"
            )
            
            Divider()
                .padding(.leading, 48)
            
            featureRow(
                icon: "eye.slash.fill",
                iconColor: .purple,
                title: "paywall.feature.noad.title",
                description: "paywall.feature.noad.desc"
            )
            
            Divider()
                .padding(.leading, 48)
            
            featureRow(
                icon: "star.fill",
                iconColor: .orange,
                title: "paywall.feature.all.title",
                description: "paywall.feature.all.desc"
            )
        }
        .padding(24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
    
    private func featureRow(icon: String, iconColor: Color, title: String, description: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(iconColor)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                
                Text(description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - 購入セクション
    private var purchaseSection: some View {
        VStack(spacing: 16) {
            if let product = store.lifetimeProduct {
                Button {
                    Task { await purchaseProduct(product) }
                } label: {
                    HStack {
                        Text("paywall.purchase.button \(product.displayPrice)")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        if isPurchasing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "arrow.right")
                                .font(.headline)
                        }
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: .blue.opacity(0.3), radius: 10, x: 0, y: 5)
                }
                .disabled(isPurchasing)
            }
            
            Text("paywall.price.note")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - プレミアム有効
    private var premiumActiveSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
            
            Text("paywall.already.premium")
                .font(.headline)
                .foregroundColor(.green)
        }
        .padding(.vertical)
    }
    
    // MARK: - 復元ボタン
    private var restoreButton: some View {
        VStack(spacing: 20) {
            Button {
                Task {
                    isPurchasing = true
                    await store.restorePurchases()
                    isPurchasing = false
                    
                    if store.isPremium {
                        alertMessage = String(localized: "paywall.purchase.restored")
                        showAlert = true
                    } else {
                        alertMessage = String(localized: "paywall.purchase.not.found")
                        showAlert = true
                    }
                }
            } label: {
                Text("paywall.restore")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .disabled(isPurchasing)
            
            policyLinks
        }
    }
    
    private var policyLinks: some View {
        HStack(spacing: 20) {
            Link(String(localized: "paywall.terms"), destination: URL(string: "https://tako-1012.github.io/riku-log-policies/terms.html")!)
            Link(String(localized: "paywall.privacy"), destination: URL(string: "https://tako-1012.github.io/riku-log-policies/privacy-policy.html")!)
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 4)
    }
    
    // MARK: - 購入処理
    private func purchaseProduct(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }

        do {
            let transaction = try await store.purchase(product)
            if transaction != nil {
                alertMessage = String(localized: "paywall.purchase.completed")
                showAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) { dismiss() }
            }
        } catch {
            alertMessage = store.errorMessage ?? (error.localizedDescription)
            showAlert = true
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreKitManager.preview())
}

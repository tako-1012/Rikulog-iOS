import SwiftUI
import Combine

@MainActor
final class AppEntitlements: ObservableObject {
    static let shared = AppEntitlements()
    
    @Published var hasPremium: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        StoreKitManager.shared.$isPremium
            .receive(on: DispatchQueue.main)
            .assign(to: \.hasPremium, on: self)
            .store(in: &cancellables)
    }
    
    // 既存のコード...
    
    /// Premium機能を使用できるか（修正版）
    var canUsePremiumFeatures: Bool {
        if isDebugPremium {
            return true
        }
        return hasPremium
    }
    
    /// 広告を表示すべきか
    var shouldShowAds: Bool {
        if isDebugPremium {
            return false
        }
        return !hasPremium
    }

    // デバッグビルドでのみ有効なフラグ。
    // Xcode の Run Scheme > Arguments に "-debug_premium_enabled YES" を追加すると Premium 状態になる。
    // 引数なし（デフォルト false）で無料ユーザーの広告・50件制限を検証できる。
    var isDebugPremium: Bool {
        #if DEBUG
        return UserDefaults.standard.bool(forKey: "debug_premium_enabled")
        #else
        return false
        #endif
    }
}

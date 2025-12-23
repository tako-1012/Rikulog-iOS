import SwiftUI
import Combine

@MainActor
final class AppEntitlements: ObservableObject {
    static let shared = AppEntitlements()
    
    @Published var hasPremium: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        // Use StoreKitManager as the single source of truth for premium state
        // (migrate away from legacy StoreManager)
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
    
    /// 広告を表示すべきか（修正版）
    var shouldShowAds: Bool {
        if isDebugPremium {
            return false
        }
        return !hasPremium
    }
    
    // デバッグビルドでは制限を緩める
    var isDebugPremium: Bool {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }
}

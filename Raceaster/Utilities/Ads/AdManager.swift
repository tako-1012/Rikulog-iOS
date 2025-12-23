import SwiftUI
import Combine

// NOTE: Placeholder ads & entitlement scaffolding.
// Replace internals with Google Mobile Ads SDK and StoreKit 2 implementation later.

final class Entitlements: ObservableObject {
    static let shared = Entitlements()
    @Published var adsEnabled: Bool = true
    @Published var hasNoAdsPurchase: Bool = false

    // In real implementation, load from StoreKit & keychain/cache
    func refresh() {
        adsEnabled = !hasNoAdsPurchase
    }

    func applyNoAdsPurchase() {
        hasNoAdsPurchase = true
        refresh()
    }
}

/// Simple banner placeholder. Swap body with AdMob banner view (GADBannerView) via UIViewRepresentable.
struct BannerPlaceholderView: View {
    @ObservedObject private var entitlements = Entitlements.shared
    var height: CGFloat = 50

    var body: some View {
        Group {
            if entitlements.adsEnabled {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.12))
                    Text("広告（バナー）")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .frame(height: height)
                .padding(.horizontal)
                .accessibilityLabel("バナー広告")
            } else {
                EmptyView()
            }
        }
    }
}

/// Reward ad facade. Wire this to AdMob RewardedAd.
final class RewardAdManager: ObservableObject {
    static let shared = RewardAdManager()
    @Published var isLoaded: Bool = false
    @Published var lastRewardDate: Date?

    func load() {
        // TODO: integrate AdMob reward load
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.isLoaded = true
        }
    }

    /// Simulate showing a reward ad. Returns whether user earned reward.
    func show(onReward: @escaping () -> Void) {
        guard isLoaded else { return }
        // TODO: present AdMob rewarded ad and call onReward on reward
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            self.lastRewardDate = Date()
            onReward()
            self.isLoaded = false
            self.load()
        }
    }
}

/// Convenience view modifier to attach a banner at bottom of a screen.
struct BannerAttached: ViewModifier {
    func body(content: Content) -> some View {
        VStack(spacing: 0) {
            content
                BannerPlaceholderView()
                .padding(.top, 8)
        }
    }
}

extension View {
    func withBanner() -> some View { self.modifier(BannerAttached()) }
}

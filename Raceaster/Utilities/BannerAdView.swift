import SwiftUI
import GoogleMobileAds
import UIKit

/// AdMobバナー広告のSwiftUIラッパー
struct BannerAdView: UIViewRepresentable {
    let adUnitID: String
    let adSize: AdSize

    /// テスト用バナー広告ID（開発中は必ずこれを使用）
    static let testBannerID = "ca-app-pub-3940256099942544/2934735716"

    /// 本番用広告ID（リリース時に使用）
    struct ProductionAdUnitIDs {
        static let unified = "ca-app-pub-6961478133837893/9398260631"
    }

    func makeUIView(context: Context) -> BannerView {
        // Determine effective ad unit ID. Allow temporary override via Info.plist key `UseTestAdUnit`
        let useTest = (Bundle.main.object(forInfoDictionaryKey: "UseTestAdUnit") as? Bool) == true
        let effectiveAdUnitID = useTest ? BannerAdView.testBannerID : adUnitID
        #if DEBUG
        print("📢 BannerAdView.makeUIView - requestedAdUnit=\(adUnitID) effectiveAdUnit=\(effectiveAdUnitID)")
        #endif

        let banner = BannerView(adSize: adSize)
        banner.adUnitID = effectiveAdUnitID
        var rootVC = getRootViewController()
        if rootVC == nil {
            // フォールバック: UIWindowScene を経由して key window の rootViewController を探す
            rootVC = UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first { $0.isKeyWindow }?.rootViewController
        }
        #if DEBUG
        if rootVC == nil {
            print("⚠️ BannerAdView: rootViewController is nil — ad may fail to present")
        } else {
            print("📌 BannerAdView: rootViewController found: \(type(of: rootVC!))")
        }
        #endif
        banner.rootViewController = rootVC
        banner.delegate = context.coordinator
        banner.load(Request())
        return banner
    }

    func updateUIView(_ uiView: BannerView, context: Context) {
        // 更新不要
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, BannerViewDelegate {
        func bannerViewDidReceiveAd(_ bannerView: BannerView) {
                #if DEBUG
                print("✅ Banner ad loaded successfully (adUnitID=\(bannerView.adUnitID ?? "unknown"))")
                #endif
        }

        func bannerView(_ bannerView: BannerView, didFailToReceiveAdWithError error: Error) {
            #if DEBUG
            print("❌ Banner ad failed to load (adUnitID=\(bannerView.adUnitID ?? "unknown")): \(error.localizedDescription)")
            #endif

            // 30秒後に再試行（指数バックオフの簡易版）
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                #if DEBUG
                print("🔄 Retrying ad load...")
                #endif
                bannerView.load(Request())
            }
        }

        func bannerViewDidRecordClick(_ bannerView: BannerView) {
            #if DEBUG
            print("👆 Banner ad clicked")
            #endif
        }

        func bannerViewWillPresentScreen(_ bannerView: BannerView) {
            #if DEBUG
            print("📱 Banner ad will present full screen")
            #endif
        }

        func bannerViewDidDismissScreen(_ bannerView: BannerView) {
            #if DEBUG
            print("📱 Banner ad dismissed")
            #endif
        }
    }

    /// ルートViewControllerを取得
    private func getRootViewController() -> UIViewController? {
        // Prefer the first scene's key window's rootViewController
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

/// Anchored adaptive banner that stretches to available width and reserves height during loading.
struct AdaptiveBannerAdView: View {
    let adUnitID: String
    var minHeight: CGFloat = 50

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let adaptiveSize = currentOrientationAnchoredAdaptiveBanner(width: width)

            BannerAdView(adUnitID: adUnitID, adSize: adaptiveSize)
                .frame(width: width, height: max(minHeight, adaptiveSize.size.height))
        }
        // Reserve space up-front to prevent layout jumps while the ad loads
        .frame(height: minHeight)
    }
}

#Preview {
    VStack {
        Text("広告プレビュー")
            .font(.headline)

        Spacer()

        AdaptiveBannerAdView(adUnitID: BannerAdView.testBannerID)
            .background(Color.gray.opacity(0.2))
    }
}

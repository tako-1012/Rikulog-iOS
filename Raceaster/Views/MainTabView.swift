import SwiftUI
import SwiftData

/// アプリのメインタブビュー
struct MainTabView: View {
    @EnvironmentObject var entitlements: AppEntitlements
    @State private var selectedTab: Int = {
        #if DEBUG
        return ScreenshotMode.initialTab
        #else
        return 0
        #endif
    }()

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $selectedTab) {
                RaceLogListView()
                    .tabItem {
                        Label("tab.records", systemImage: "list.bullet.clipboard.fill")
                    }
                    .tag(0)

                PaceCalculatorView()
                    .tabItem {
                        Label("tab.calculator", systemImage: "stopwatch.fill")
                    }
                    .tag(1)

                ProfileView()
                    .tabItem {
                        Label("tab.profile", systemImage: "person.crop.circle.fill")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("tab.settings", systemImage: "gearshape.fill")
                    }
                    .tag(3)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if entitlements.shouldShowAds {
                AdaptiveBannerAdView(adUnitID: BannerAdView.ProductionAdUnitIDs.unified)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -6)
                    .background(Color(UIColor.systemBackground))
            }
        }
        // キーボード表示時にタブバーと広告バナーが持ち上がらないようにする
        // （各タブ内のフォームは自身でキーボードを避ける）
        .ignoresSafeArea(.keyboard, edges: .bottom)
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RaceRecord.self, Lap.self, RaceDistance.self], inMemory: true)
}

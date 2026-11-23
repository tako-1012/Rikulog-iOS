import SwiftUI
import SwiftData

/// アプリのメインタブビュー
struct MainTabView: View {
    @EnvironmentObject var entitlements: AppEntitlements

    var body: some View {
        VStack(spacing: 0) {
            TabView {
                RaceLogListView()
                    .tabItem {
                        Label("tab.records", systemImage: "list.bullet.clipboard.fill")
                    }

                PaceCalculatorView()
                    .tabItem {
                        Label("tab.calculator", systemImage: "stopwatch.fill")
                    }

                ProfileView()
                    .tabItem {
                        Label("tab.profile", systemImage: "person.crop.circle.fill")
                    }

                SettingsView()
                    .tabItem {
                        Label("tab.settings", systemImage: "gearshape.fill")
                    }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if entitlements.shouldShowAds {
                AdaptiveBannerAdView(adUnitID: BannerAdView.ProductionAdUnitIDs.unified)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -6)
                    .background(Color(UIColor.systemBackground))
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RaceRecord.self, Lap.self, RaceDistance.self], inMemory: true)
}

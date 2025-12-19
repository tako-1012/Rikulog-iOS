import SwiftUI

/// アプリのメインタブビュー
struct MainTabView: View {
    var body: some View {
        TabView {
            PaceCalculatorView()
                .tabItem {
                    Label("ペース計算", systemImage: "timer")
                }
            
            RaceLogListView()
                .tabItem {
                    Label("レース記録", systemImage: "list.bullet")
                }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RaceRecord.self, Lap.self], inMemory: true)
}

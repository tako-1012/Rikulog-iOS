import SwiftUI
import SwiftData

@main
struct RaceMasterApp: App {
    var body: some Scene {
        WindowGroup {
            MainTabView()
        }
        .modelContainer(for: [RaceRecord.self, Lap.self])
    }
}

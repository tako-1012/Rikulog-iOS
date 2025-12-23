import SwiftUI
import SwiftData

/// アプリのメインタブビュー
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    @Query private var userProfiles: [UserProfile]
    var body: some View {
        TabView {
            RaceLogListView()
                .tabItem {
                    Label("記録", systemImage: "list.bullet.clipboard.fill")
                }
            
            PaceCalculatorView()
                .tabItem {
                    Label("計算", systemImage: "stopwatch.fill")
                }
            
            ProfileView()
                .tabItem {
                    Label("プロフィール", systemImage: "person.crop.circle.fill")
                }
            
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape.fill")
                }
        }
        .onAppear {
            // 起動時初期化: ユーザープロファイルとデフォルト種目を不足分だけ作成
            Task {
                if userProfiles.isEmpty {
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    try? modelContext.save()
                }

                // Smart seeding: for each default distance, only insert if an equivalent
                // distance for the same raceType does not already exist.
                let defaults = RaceDistance.createDefaultDistances()
                var inserted = 0
                for d in defaults {
                    let exists = distances.contains { existing in
                        abs(existing.distanceKm - d.distanceKm) < 0.0001 && existing.raceType == d.raceType
                    }
                    if !exists {
                        modelContext.insert(d)
                        inserted += 1
                    }
                }
                if inserted > 0 { try? modelContext.save() }

                // 起動時に自動で重複をクリーンアップ（iCloud同期による重複を解消）
                await performAutoDedupeIfNeeded()

                // マイグレーション：既存のロード記録の小数秒を切り上げて公式表示に合わせる
                var changed = 0
                for r in races where r.raceType == .road {
                    let ceilVal = ceil(r.totalTime)
                    if r.totalTime != ceilVal {
                        r.totalTime = ceilVal
                        changed += 1
                    }
                    if let off = r.officialTime {
                        let newOff = ceil(off)
                        if off != newOff { r.officialTime = newOff; changed += 1 }
                    }
                }
                if changed > 0 {
                    try? modelContext.save()
                    print("Migration: normalized \(changed) road times to integer seconds")
                }
            }
        }
    }
}

#Preview {
    MainTabView()
        .modelContainer(for: [RaceRecord.self, Lap.self, RaceDistance.self], inMemory: true)
}

// MARK: - Auto Dedupe
extension MainTabView {
    /// Perform automatic deduplication of `RaceDistance` entries.
    /// Groups by (raceType, distanceKm rounded) and keeps a single representative.
    @MainActor
    private func performAutoDedupeIfNeeded() async {
        let all = distances
        var groups: [String: [RaceDistance]] = [:]
        for d in all {
            let key = "\(d.raceType.rawValue)-\(String(format: "%.6f", d.distanceKm))"
            groups[key, default: []].append(d)
        }

        var deleted = 0
        for (_, items) in groups {
            if items.count <= 1 { continue }
            // Keep the first item in the group and delete the rest.
            // The query order is used to determine which one is considered the "first".
            let duplicates = items.dropFirst()
            for dup in duplicates {
                modelContext.delete(dup)
                deleted += 1
            }
        }

        // Always attempt to save (no-op when nothing deleted)
        do { try modelContext.save() } catch { print("Auto-dedupe save failed: \(error)") }
        if deleted > 0 { print("Auto dedupe completed. Deleted \(deleted) duplicate RaceDistance entries.") }
    }
}

import SwiftUI
import SwiftData

/// アプリのメインタブビュー
struct MainTabView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    @Query private var userProfiles: [UserProfile]
    @EnvironmentObject var entitlements: AppEntitlements
    var body: some View {
        VStack(spacing: 0) {
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
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if entitlements.shouldShowAds {
                AdaptiveBannerAdView(adUnitID: BannerAdView.ProductionAdUnitIDs.unified)
                    .frame(maxWidth: .infinity)
                    .padding(.top, -6) // tighten gap between tab bar and banner
                    .background(Color(UIColor.systemBackground))
            }
        }
        .onAppear {
            // 起動時初期化: ユーザープロファイルとデフォルト種目を不足分だけ作成
            Task {
                if userProfiles.isEmpty {
                    let newProfile = UserProfile()
                    modelContext.insert(newProfile)
                    do { try modelContext.save() } catch { print("⚠️ UserProfile save failed: \(error)") }
                }

                // Smart seeding: for each default distance, only insert if an equivalent
                // distance for the same raceType does not already exist.
                // ユーザーが削除した種目は復活させない
                let defaults = RaceDistance.createDefaultDistances()
                var inserted = 0
                for d in defaults {
                    let exists = distances.contains { existing in
                        abs(existing.distanceKm - d.distanceKm) < 0.0001 && existing.raceType == d.raceType && existing.name == d.name
                    }
                    
                    // ユーザーが削除したデフォルト種目でないかチェック
                    let isDeleted = isDefaultDistanceDeleted(d)
                    
                    if !exists && !isDeleted {
                        modelContext.insert(d)
                        inserted += 1
                    }
                }
                if inserted > 0 { do { try modelContext.save() } catch { print("⚠️ Default distances save failed: \(error)") } }

                // 起動時に自動で重複をクリーンアップ（iCloud同期による重複を解消）
                RaceDistanceDeduplicator.deduplicateDistances(distances, in: modelContext)

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
                    do { try modelContext.save() } catch { print("⚠️ Road time migration save failed: \(error)") }
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

// MARK: - Helpers
extension MainTabView {
    /// ユーザーが削除したデフォルト種目かどうかをチェック
    private func isDefaultDistanceDeleted(_ distance: RaceDistance) -> Bool {
        let key = "deletedDefaultDistances"
        let deletedIds = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        
        return deletedIds.contains { dict in
            let dkm = dict["distanceKm"] as? Double ?? 0
            let rtype = dict["raceType"] as? String ?? ""
            let dname = dict["name"] as? String ?? ""
            return abs(dkm - distance.distanceKm) < 0.0001 && rtype == distance.raceType.rawValue && dname == distance.name
        }
    }
}

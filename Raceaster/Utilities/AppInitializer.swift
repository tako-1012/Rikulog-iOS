import Foundation
import SwiftData

/// アプリ起動時の初期化・マイグレーションを一元管理するサービス。
/// `RaceMasterApp.init()` から呼び出す。View 層には配置しない。
enum AppInitializer {

    static func run(in container: ModelContainer) {
        let context = ModelContext(container)
        insertDefaultProfileIfNeeded(context: context)
        seedDefaultDistancesIfNeeded(context: context)
        migrateRoadTimesIfNeeded(context: context)
    }

    // MARK: - ユーザープロファイルの初期作成

    private static func insertDefaultProfileIfNeeded(context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<UserProfile>())) ?? 0
        guard count == 0 else { return }
        context.insert(UserProfile())
        do { try context.save() } catch { print("⚠️ UserProfile save failed: \(error)") }
    }

    // MARK: - デフォルト種目の初期挿入

    private static func seedDefaultDistancesIfNeeded(context: ModelContext) {
        let existing = (try? context.fetch(FetchDescriptor<RaceDistance>())) ?? []
        let defaults = RaceDistance.createDefaultDistances()
        var inserted = 0
        for d in defaults {
            let exists = existing.contains { e in
                abs(e.distanceKm - d.distanceKm) < 0.0001 && e.raceType == d.raceType && e.name == d.name
            }
            if !exists && !isDefaultDistanceDeleted(d) {
                context.insert(d)
                inserted += 1
            }
        }
        if inserted > 0 {
            do { try context.save() } catch { print("⚠️ Default distances save failed: \(error)") }
        }
    }

    // MARK: - ロード記録の秒数切り上げマイグレーション

    private static func migrateRoadTimesIfNeeded(context: ModelContext) {
        let races = (try? context.fetch(FetchDescriptor<RaceRecord>())) ?? []
        var changed = 0
        for r in races where r.raceType.shouldCeilTime {
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
            do { try context.save() } catch { print("⚠️ Road time migration save failed: \(error)") }
            print("Migration: normalized \(changed) road times to integer seconds")
        }
    }

    // MARK: - ユーザーが削除したデフォルト種目の判定

    private static func isDefaultDistanceDeleted(_ distance: RaceDistance) -> Bool {
        let key = "deletedDefaultDistances"
        let deletedIds = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        return deletedIds.contains { dict in
            let dkm = dict["distanceKm"] as? Double ?? 0
            let rtype = dict["raceType"] as? String ?? ""
            let dname = dict["name"] as? String ?? ""
            return abs(dkm - distance.distanceKm) < 0.0001 &&
                   rtype == distance.raceType.rawValue &&
                   dname == distance.name
        }
    }
}

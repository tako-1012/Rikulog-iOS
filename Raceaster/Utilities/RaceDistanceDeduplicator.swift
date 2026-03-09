import Foundation
import SwiftData

/// `RaceDistance` の重複除去を一元管理するユーティリティ。
/// 種目（raceType）＋距離km（丸め）でグルーピングし、先頭以外を削除します。
enum RaceDistanceDeduplicator {

    // MARK: - ModelContainer ベース（App起動直後用）

    /// 新しい `ModelContext` を作成し、`RaceDistance` の重複をクリーンアップする。
    /// - Parameter container: `ModelContainer`
    /// - Returns: 削除した重複エントリ数
    @discardableResult
    static func deduplicateDistances(in container: ModelContainer) -> Int {
        let context = ModelContext(container)
        do {
            let all = try context.fetch(FetchDescriptor<RaceDistance>())
            let deleted = performDedup(all, in: context)
            if deleted > 0 {
                try context.save()
            }
            return deleted
        } catch {
            print("⚠️ RaceDistanceDeduplicator (container) failed: \(error)")
            return 0
        }
    }

    // MARK: - 既存の配列 + ModelContext ベース（View用）

    /// 渡された配列の中から重複を検出し、`ModelContext` で削除する。
    /// - Parameters:
    ///   - distances: 現在取得済みの `RaceDistance` 配列
    ///   - context: 削除に使う `ModelContext`
    /// - Returns: 削除した重複エントリ数
    @MainActor
    @discardableResult
    static func deduplicateDistances(_ distances: [RaceDistance], in context: ModelContext) -> Int {
        let deleted = performDedup(distances, in: context)
        do {
            try context.save()
        } catch {
            print("⚠️ RaceDistanceDeduplicator (context) save failed: \(error)")
        }
        return deleted
    }

    // MARK: - Private

    private static func performDedup(_ distances: [RaceDistance], in context: ModelContext) -> Int {
        guard !distances.isEmpty else { return 0 }

        var groups: [String: [RaceDistance]] = [:]
        for d in distances {
            let key = "\(d.raceType.rawValue)-\(String(format: "%.6f", d.distanceKm))-\(d.name)"
            groups[key, default: []].append(d)
        }

        var deleted = 0
        for (_, items) in groups {
            guard items.count > 1 else { continue }
            // 先頭を残して残りを削除
            for dup in items.dropFirst() {
                context.delete(dup)
                deleted += 1
            }
        }
        return deleted
    }
}

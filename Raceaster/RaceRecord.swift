import Foundation
import SwiftData

/// 大会の記録を表すモデル（親エンティティ）
@Model
final class RaceRecord {
    /// 大会名
    var raceName: String
    
    /// 開催日
    var date: Date
    
    /// 総距離（km）
    var totalDistance: Double
    
    /// 総タイム（秒）
    var totalTime: Int
    
    /// メモ
    var memo: String
    
    /// ラップタイムのリスト（子エンティティ）
    @Relationship(deleteRule: .cascade, inverse: \Lap.raceRecord)
    var laps: [Lap]
    
    /// VDOT値（計算プロパティ）
    var vdot: Double {
        return VDOTCalculator.calculateVDOT(distanceKm: totalDistance, timeSeconds: totalTime)
    }
    
    /// 平均ペース（秒/km）
    var averagePace: Double {
        guard totalDistance > 0 else { return 0 }
        return Double(totalTime) / totalDistance
    }
    
    init(
        raceName: String,
        date: Date,
        totalDistance: Double,
        totalTime: Int,
        memo: String = "",
        laps: [Lap] = []
    ) {
        self.raceName = raceName
        self.date = date
        self.totalDistance = totalDistance
        self.totalTime = totalTime
        self.memo = memo
        self.laps = laps
    }
}

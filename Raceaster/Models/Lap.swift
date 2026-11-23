import Foundation
import SwiftData

/// ラップタイムを表すモデル（子エンティティ）
@Model
final class Lap {
    var id: UUID = UUID()
    /// ラップ番号
    var lapNumber: Int = 0
    
    /// 区間距離（km）
    var distance: Double = 0.0
    
    /// 区間タイム（秒, 小数点以下対応）
    var time: Double = 0.0
    
    /// 親レコード（RaceRecord）への参照
    @Relationship
    var raceRecord: RaceRecord?
    
    /// 区間ペース（秒/km）
    var pace: Double {
        guard distance > 0, time >= 0 else { return 0 }
        return Double(time) / distance
    }
    
    init(
        lapNumber: Int,
        distance: Double,
        time: Double
    ) {
        self.lapNumber = lapNumber
        self.distance = distance
        self.time = time
    }

    /// `LapInput`（入力用一時モデル）から `Lap`（永続モデル）を生成する
    static func from(_ input: LapInput, lapNumber: Int) -> Lap {
        Lap(lapNumber: lapNumber, distance: input.distance, time: input.time)
    }
}

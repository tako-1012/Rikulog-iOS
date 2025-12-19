import Foundation
import SwiftData

/// ラップタイムを表すモデル（子エンティティ）
@Model
final class Lap {
    /// ラップ番号
    var lapNumber: Int
    
    /// 区間距離（km）
    var distance: Double
    
    /// 区間タイム（秒）
    var time: Int
    
    /// 親レコード（RaceRecord）への参照
    var raceRecord: RaceRecord?
    
    /// 区間ペース（秒/km）
    var pace: Double {
        guard distance > 0 else { return 0 }
        return Double(time) / distance
    }
    
    init(
        lapNumber: Int,
        distance: Double,
        time: Int
    ) {
        self.lapNumber = lapNumber
        self.distance = distance
        self.time = time
    }
}

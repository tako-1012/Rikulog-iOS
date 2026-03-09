import Foundation
import SwiftData

/// レース種目（距離）を管理するモデル
@Model
final class RaceDistance {
    /// 種目名（例: "5000m", "フルマラソン"）
    var name: String = String()
    
    /// 距離（km単位）
    var distanceKm: Double = 0.0
    
    /// レース種類（保存用文字列）
    var raceTypeRaw: String = RaceType.road.rawValue

    /// レース種類（計算プロパティ）
    var raceType: RaceType {
        get { RaceType(rawValue: raceTypeRaw) ?? .road }
        set { raceTypeRaw = newValue.rawValue }
    }
    
    /// 表示順序
    var sortOrder: Int = 0
    
    init(name: String, distanceKm: Double, raceType: RaceType, sortOrder: Int = 0) {
        self.name = name
        self.distanceKm = distanceKm
        self.raceType = raceType
        self.sortOrder = sortOrder
    }
    
    /// デフォルトの種目リストを作成
    static func createDefaultDistances() -> [RaceDistance] {
        return [
            // スプリント
            RaceDistance(name: "100m", distanceKm: 0.1, raceType: .track, sortOrder: 0),
            RaceDistance(name: "200m", distanceKm: 0.2, raceType: .track, sortOrder: 1),
            RaceDistance(name: "300m", distanceKm: 0.3, raceType: .track, sortOrder: 2),
            RaceDistance(name: "400m", distanceKm: 0.4, raceType: .track, sortOrder: 3),
            
            // トラック種目
            RaceDistance(name: "800m", distanceKm: 0.8, raceType: .track, sortOrder: 4),
            RaceDistance(name: "1500m", distanceKm: 1.5, raceType: .track, sortOrder: 5),
            RaceDistance(name: "3000m", distanceKm: 3.0, raceType: .track, sortOrder: 6),
            RaceDistance(name: "3000mSC", distanceKm: 3.0, raceType: .track, sortOrder: 7),
            RaceDistance(name: "5000m", distanceKm: 5.0, raceType: .track, sortOrder: 8),
            RaceDistance(name: "10000m", distanceKm: 10.0, raceType: .track, sortOrder: 9),
            
            // ロード種目
            RaceDistance(name: "5km", distanceKm: 5.0, raceType: .road, sortOrder: 10),
            RaceDistance(name: "10km", distanceKm: 10.0, raceType: .road, sortOrder: 11),
            RaceDistance(name: "ハーフマラソン", distanceKm: 21.0975, raceType: .road, sortOrder: 12),
            RaceDistance(name: "30km", distanceKm: 30.0, raceType: .road, sortOrder: 13),
            RaceDistance(name: "フルマラソン", distanceKm: 42.195, raceType: .road, sortOrder: 14),
            
            // その他
            RaceDistance(name: "ウルトラマラソン", distanceKm: 100.0, raceType: .other, sortOrder: 20),
        ]
    }
    
    /// 指定距離がこの種目の許容範囲内かどうかを判定
    /// - Parameter distance: 比較する距離（km）
    /// - Returns: 許容範囲内ならtrue
    func matches(distance: Double) -> Bool {
        let tolerance = distanceKm * 0.02  // ±2%
        let minDistance = distanceKm - tolerance
        let maxDistance = distanceKm + tolerance
        return distance >= minDistance && distance <= maxDistance
    }
}

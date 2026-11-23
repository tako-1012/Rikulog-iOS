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

    // MARK: - フィールド種目専用フィールド（Optional、既存データに影響なし）

    /// サブカテゴリ（フィールド種目用："jump" / "throw"）
    var subcategoryRaw: String? = nil

    /// 記録の種別（フィールド種目用："distance" / "height"）
    var recordTypeRaw: String? = nil

    /// フィールド種目かどうか
    var isFieldEvent: Bool { raceType == .field }

    /// 高さを競う種目かどうか（走高跳・棒高跳）
    var isHeightEvent: Bool { recordTypeRaw == "height" }

    /// ローカライズされた種目名。デフォルト種目はロケールに応じた名称を返し、カスタム種目は保存名をそのまま返す。
    var localizedName: String {
        let keyMap: [String: String] = [
            "ハーフマラソン": "distance.half.marathon",
            "フルマラソン":   "distance.full.marathon",
            "ウルトラマラソン": "distance.ultra.marathon",
            "走幅跳":  "distance.long.jump",
            "三段跳":  "distance.triple.jump",
            "走高跳":  "distance.high.jump",
            "棒高跳":  "distance.pole.vault",
            "砲丸投":  "distance.shot.put",
            "円盤投":  "distance.discus.throw",
            "ハンマー投": "distance.hammer.throw",
            "やり投":  "distance.javelin.throw",
        ]
        if let key = keyMap[name] {
            return String(localized: String.LocalizationValue(stringLiteral: key))
        }
        return name
    }

    init(name: String, distanceKm: Double, raceType: RaceType, sortOrder: Int = 0,
         subcategoryRaw: String? = nil, recordTypeRaw: String? = nil) {
        self.name = name
        self.distanceKm = distanceKm
        self.raceType = raceType
        self.sortOrder = sortOrder
        self.subcategoryRaw = subcategoryRaw
        self.recordTypeRaw = recordTypeRaw
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

            // フィールド種目（跳躍）
            // distanceKm は実走距離ではなく種目識別用の固有値（201〜208）
            RaceDistance(name: "走幅跳", distanceKm: 201.0, raceType: .field, sortOrder: 100,
                         subcategoryRaw: "jump", recordTypeRaw: "distance"),
            RaceDistance(name: "三段跳", distanceKm: 202.0, raceType: .field, sortOrder: 101,
                         subcategoryRaw: "jump", recordTypeRaw: "distance"),
            RaceDistance(name: "走高跳", distanceKm: 203.0, raceType: .field, sortOrder: 102,
                         subcategoryRaw: "jump", recordTypeRaw: "height"),
            RaceDistance(name: "棒高跳", distanceKm: 204.0, raceType: .field, sortOrder: 103,
                         subcategoryRaw: "jump", recordTypeRaw: "height"),

            // フィールド種目（投擲）
            RaceDistance(name: "砲丸投", distanceKm: 205.0, raceType: .field, sortOrder: 110,
                         subcategoryRaw: "throw", recordTypeRaw: "distance"),
            RaceDistance(name: "円盤投", distanceKm: 206.0, raceType: .field, sortOrder: 111,
                         subcategoryRaw: "throw", recordTypeRaw: "distance"),
            RaceDistance(name: "ハンマー投", distanceKm: 207.0, raceType: .field, sortOrder: 112,
                         subcategoryRaw: "throw", recordTypeRaw: "distance"),
            RaceDistance(name: "やり投", distanceKm: 208.0, raceType: .field, sortOrder: 113,
                         subcategoryRaw: "throw", recordTypeRaw: "distance"),
        ]
    }
    
    /// 指定距離がこの種目の許容範囲内かどうかを判定
    /// - Parameter distance: 比較する距離（km）
    /// - Returns: 許容範囲内ならtrue
    func matches(distance: Double) -> Bool {
        // フィールド種目の distanceKm は実走距離ではなく種目識別用の固有値のため、
        // ±2% 許容範囲を使うと隣接値と重なる。厳密な等値比較を使用する。
        if raceType == .field {
            return abs(distanceKm - distance) < 0.001
        }
        let tolerance = distanceKm * 0.02  // ±2%
        let minDistance = distanceKm - tolerance
        let maxDistance = distanceKm + tolerance
        return distance >= minDistance && distance <= maxDistance
    }
}

// MARK: - Collection helpers

extension Array where Element == RaceDistance {
    /// 同一種目・同一距離の重複を除去して返す（順序を保持）
    func unique() -> [RaceDistance] {
        var seen: Set<String> = []
        var result: [RaceDistance] = []
        for d in self {
            let key = "\(d.raceType.rawValue)-\(String(format: "%.6f", d.distanceKm))"
            if seen.insert(key).inserted {
                result.append(d)
            }
        }
        return result
    }
}

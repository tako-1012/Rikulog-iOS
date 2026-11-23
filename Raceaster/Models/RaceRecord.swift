import Foundation
import SwiftData

/// レースの種類
enum RaceType: String, Codable, CaseIterable {
    case road = "road"       // ロード
    case track = "track"     // トラック
    case other = "other"     // その他
    case field = "field"     // フィールド種目（跳躍・投擲）

    var displayName: String {
        switch self {
        case .road: return String(localized: "race.type.road.display")
        case .track: return String(localized: "race.type.track.display")
        case .other: return String(localized: "race.type.other.display")
        case .field: return String(localized: "race.type.field.display")
        }
    }

    var iconName: String {
        switch self {
        case .road: return "road.lanes"
        case .track: return "figure.run.circle"
        case .other: return "flag.checkered"
        case .field: return "figure.gymnastics"
        }
    }

    /// タイム（秒）を記録する種目か。false はフィールド種目（距離・高さで記録）
    var usesTime: Bool {
        switch self {
        case .track, .road, .other: return true
        case .field: return false
        }
    }

    /// VDOT 計算対象にできる種目か
    var supportsVDOT: Bool {
        switch self {
        case .track, .road, .other: return true
        case .field: return false
        }
    }

    /// 保存時にタイムを整数秒に切り上げる種目か
    var shouldCeilTime: Bool {
        switch self {
        case .road: return true
        case .track, .other, .field: return false
        }
    }

    /// 記録が小さいほど優秀か（false = 大きいほど優秀 = フィールド種目）
    var smallerIsBetter: Bool {
        switch self {
        case .track, .road, .other: return true
        case .field: return false
        }
    }
}

/// トラック競技会の種別
enum TrackMeetType: String, Codable {
    case timeTrial = "timeTrial"     // 記録会
    case preliminary = "preliminary" // 予選
    case final = "final"             // 決勝
    
    var displayName: String {
        switch self {
        case .timeTrial: return String(localized: "race.meet.timetrial.display")
        case .preliminary: return String(localized: "race.meet.preliminary.display")
        case .final: return String(localized: "race.meet.final.display")
        }
    }
}

/// 大会の記録を表すモデル（親エンティティ）
@Model
final class RaceRecord {
    /// 一意識別子
    var id: UUID = UUID()
    /// 大会名
    var raceName: String = ""
    
    /// 開催日
    var date: Date = Date()
    
    /// レースの種類
    var raceTypeRaw: String = RaceType.road.rawValue {
        didSet { normalizeTimes() }
    }

    var raceType: RaceType {
        get { RaceType(rawValue: raceTypeRaw) ?? .road }
        set { raceTypeRaw = newValue.rawValue }
    }
    
    /// 総距離（km）
    var totalDistance: Double = 0.0
    
    /// 総タイム（秒, 小数点以下対応）
    var totalTime: Double = 0.0
    
    /// 正式タイム（手動・機械計測の差異を記録, 小数点以下対応）
    var officialTime: Double?
    
    /// メモ
    var memo: String = ""
    
    /// トラック競技会の種別（トラックの場合のみ）
    var trackMeetType: TrackMeetType?
    
    /// 順位（トラックの場合のみ）
    var ranking: Int?
    
    /// 組（予選・記録会用）
    var group: Int?
    
    /// 駅伝フラグ（ロードの場合のみ）
    var isRelay: Bool = false
    
    /// 駅伝区間（ロード駅伝の場合のみ）
    var relayStage: Int?
    
    /// VDOT計測に含めるか
    var includeInVDOT: Bool = true

    // MARK: - フィールド種目専用フィールド（すべてOptional、既存データに影響なし）

    /// 記録（m）：水平跳躍（走幅跳・三段跳）および投擲種目
    var fieldDistance: Double? = nil

    /// 記録（m）：垂直跳躍（走高跳・棒高跳）
    var fieldHeight: Double? = nil

    /// 試技結果（JSON文字列で保存）
    var attemptResults: String? = nil

    /// 風速（m/s）：跳躍種目の参考記録判定用
    var windSpeed: Double? = nil

    /// 追い風参考記録フラグ（追い風2.0m/s超の場合 true）
    var isWindAided: Bool? = nil

    /// ラップタイムのリスト（子エンティティ）
    /// CloudKit ではリレーションは必ず Optional にする必要があるため Optional を採用
    @Relationship(deleteRule: .cascade, inverse: \Lap.raceRecord)
    var laps: [Lap]? = nil
    
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
        raceType: RaceType = .road,
        totalDistance: Double,
        totalTime: Double,
        memo: String = "",
        trackMeetType: TrackMeetType? = nil,
        ranking: Int? = nil,
        laps: [Lap]? = nil,
        officialTime: Double? = nil,
        includeInVDOT: Bool = true,
        group: Int? = nil,
        isRelay: Bool = false,
        relayStage: Int? = nil
    ) {
        self.id = UUID()
        self.raceName = raceName
        self.date = date
        self.raceType = raceType
        self.totalDistance = totalDistance
        // ロード種目は保存時に小数点以下を切り上げる（公式記録に合わせる）
        self.totalTime = raceType.shouldCeilTime ? ceil(totalTime) : totalTime
        self.memo = memo
        self.trackMeetType = trackMeetType
        self.ranking = ranking
        self.laps = laps
        // 公式タイムも同様に扱う
        if let off = officialTime {
            self.officialTime = raceType.shouldCeilTime ? ceil(off) : off
        } else {
            self.officialTime = nil
        }
        self.includeInVDOT = includeInVDOT
        self.group = group
        self.isRelay = isRelay
        self.relayStage = relayStage
    }

    /// 外部から totalTime をセットする際に種目に応じた正規化を行う
    func setTotalTimeFromInput(_ seconds: Double) {
        self.totalTime = raceType.shouldCeilTime ? ceil(seconds) : seconds
    }

    func setOfficialTimeFromInput(_ seconds: Double?) {
        guard let s = seconds else { self.officialTime = nil; return }
        self.officialTime = raceType.shouldCeilTime ? ceil(s) : s
    }

    private func normalizeTimes() {
        guard raceType.shouldCeilTime else { return }
        if totalTime != ceil(totalTime) { totalTime = ceil(totalTime) }
        if let off = officialTime, off != ceil(off) { officialTime = ceil(off) }
    }

    // raceType が変更された場合に時間の正規化を行う（外部から raceTypeRaw を直接変更するケースに備える）
}

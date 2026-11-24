#if DEBUG
import Foundation
import SwiftData

/// App Store 用スクリーンショット撮影モード（DEBUG ビルド専用）
///
/// 起動引数の例:
///   -screenshotMode YES -screenshotScreen records -debug_premium_enabled YES
///   -AppleLanguages "(en)" -AppleLocale en_US
///
/// screenshotScreen: records / detail / pb / share / calculator / treadmill / profile
enum ScreenshotMode {
    static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: "screenshotMode")
    }

    static var screen: String {
        UserDefaults.standard.string(forKey: "screenshotScreen") ?? ""
    }

    /// 起動時に選択するタブ（0: 記録, 1: 計算, 2: プロフィール, 3: 設定）
    static var initialTab: Int {
        guard isEnabled else { return 0 }
        switch screen {
        case "calculator", "treadmill": return 1
        case "profile": return 2
        default: return 0
        }
    }

    /// 詳細画面・祝福画面・シェア画面で使う記録の大会名
    static var featuredRaceName: String { name("Autumn Classic", "秋季記録会") }

    /// 撮影言語に応じてデモデータの名前を切り替える
    private static var isJapanese: Bool {
        Locale.preferredLanguages.first?.hasPrefix("ja") ?? false
    }

    private static func name(_ en: String, _ ja: String) -> String {
        isJapanese ? ja : en
    }

    // MARK: - デモデータ

    /// 既存の記録とプロフィールを削除し、デモデータを投入する
    static func seedDemoData(in container: ModelContainer) {
        guard isEnabled else { return }
        let context = ModelContext(container)

        try? context.delete(model: Lap.self)
        try? context.delete(model: RaceRecord.self)

        // プロフィール
        let profiles = (try? context.fetch(FetchDescriptor<UserProfile>())) ?? []
        let profile = profiles.first ?? {
            let p = UserProfile()
            context.insert(p)
            return p
        }()
        profile.name = name("Jordan Lee", "佐藤 陸")
        profile.club = name("Riverside Track Club", "さくら陸上クラブ")

        func date(_ y: Int, _ m: Int, _ d: Int) -> Date {
            Calendar.current.date(from: DateComponents(year: y, month: m, day: d)) ?? Date()
        }

        func race(_ name: String, _ date: Date, _ type: RaceType, _ km: Double, _ time: Double,
                  meet: TrackMeetType? = nil, rank: Int? = nil, laps: [Lap]? = nil) -> RaceRecord {
            let r = RaceRecord(raceName: name, date: date, raceType: type, totalDistance: km,
                               totalTime: time, trackMeetType: meet, ranking: rank, laps: laps,
                               officialTime: time)
            laps?.forEach { $0.raceRecord = r; context.insert($0) }
            context.insert(r)
            return r
        }

        // 注目の 5000m（ラップつき・自己ベスト）
        let lapTimes: [Double] = [72.1, 73.4, 73.8, 74.2, 73.6, 73.9, 74.0, 73.5, 73.1, 72.6, 71.9, 71.0]
        let total5000 = 15 * 60 + 15.0
        var laps = lapTimes.enumerated().map { i, t in Lap(lapNumber: i + 1, distance: 0.4, time: t) }
        laps.append(Lap(lapNumber: 13, distance: 0.2, time: total5000 - lapTimes.reduce(0, +)))
        _ = race(featuredRaceName, date(2026, 9, 20), .track, 5.0, total5000, meet: .final, rank: 2, laps: laps)

        _ = race(name("Summer Twilight Meet", "夏季ナイター記録会"), date(2026, 6, 7), .track, 5.0, 15 * 60 + 31.65, meet: .final, rank: 4)
        _ = race(name("Spring Distance Carnival", "春季長距離記録会"), date(2026, 4, 12), .track, 5.0, 15 * 60 + 48.20, meet: .timeTrial)
        _ = race(name("Riverside Invitational", "招待陸上競技大会"), date(2026, 5, 17), .track, 1.5, 4 * 60 + 1.83, meet: .final, rank: 3)
        _ = race(name("Midsummer Night Meet", "真夏のナイター陸上"), date(2026, 7, 5), .track, 0.8, 2 * 60 + 3.10, meet: .preliminary, rank: 1)
        _ = race(name("City Championships", "市民陸上選手権"), date(2026, 10, 18), .track, 10.0, 32 * 60 + 10.45, meet: .final, rank: 5)
        _ = race(name("Harbor 10K", "港町10kmロードレース"), date(2026, 3, 8), .road, 10.0, 32 * 60 + 45, rank: 12)
        _ = race(name("Valley Half Marathon", "川沿いハーフマラソン"), date(2026, 2, 15), .road, 21.0975, 3600 + 11 * 60 + 52, rank: 9)
        _ = race(name("Coastal Marathon", "海岸線マラソン"), date(2025, 12, 7), .road, 42.195, 2 * 3600 + 34 * 60 + 18, rank: 21)

        // フィールド種目（走幅跳）
        for (title, d, mark) in [(name("Spring Jumps Festival", "春季跳躍競技会"), date(2026, 5, 30), 6.62),
                                (name("Regional Open", "地区オープン大会"), date(2026, 8, 23), 6.85)] {
            let r = RaceRecord(raceName: title, date: d, raceType: .field, totalDistance: 201.0,
                               totalTime: 1.0, includeInVDOT: false)
            r.fieldDistance = mark
            r.windSpeed = 1.2
            r.isWindAided = false
            context.insert(r)
        }

        try? context.save()
    }
}
#endif

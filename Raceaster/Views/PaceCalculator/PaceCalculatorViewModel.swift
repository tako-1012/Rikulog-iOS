import SwiftUI
import SwiftData
import Combine

/// ペース計算のViewModel
@MainActor
class PaceCalculatorViewModel: ObservableObject {
    @Published var distances: [RaceDistance] = []
    @Published var distance: String = ""
    @Published var selectedDistanceId: PersistentIdentifier? = nil
    private var isApplyingDistanceSelection = false
    @Published var hoursText: String = ""
    @Published var minutesText: String = ""
    @Published var secondsText: String = ""
    @Published var paceMinutesText: String = ""
    @Published var paceSecondsText: String = ""
    @Published var mode: CalculationMode = .calculatePace
    @Published var resultText: String = ""
    @Published var lapPreset: String = "400m"
    @Published var customLapText: String = ""
    @Published var customLapUnit: String = "m" // "m" または "km"
    @Published var autoLaps: [Double] = []
    @Published var computedPaceSecondsPerKm: Double? = nil
    @Published var selectedRaceType: RaceType? = nil
    @Published var selectedDistanceName: String? = nil
    
    enum CalculationMode {
        case calculatePace
        case calculateTime
        case calculateDistance
    }
    
    /// 時間フィールドを正規化（TimeInputNormalizer ユーティリティを利用）
    func normalizeTimeFields() {
        let normalized = TimeInputNormalizer.normalize(hoursText: hoursText, minutesText: minutesText, secondsText: secondsText)
        hoursText = normalized.hours
        minutesText = normalized.minutes
        secondsText = normalized.seconds
    }
    
    /// ペース（分秒）フィールドを正規化（TimeInputNormalizer ユーティリティを利用）
    func normalizePaceFields() {
        let normalized = TimeInputNormalizer.normalize(hoursText: "", minutesText: paceMinutesText, secondsText: paceSecondsText)
        paceMinutesText = normalized.minutes
        paceSecondsText = normalized.seconds
    }
    
    /// ペースを計算
    func calculatePace() {
        guard let dist = Double(distance), dist > 0 else {
            resultText = "有効な距離を入力してください"
            return
        }
        guard dist <= 1000 else {
            resultText = "距離が範囲外です（1000km以下）"
            return
        }
        let h = Int(hoursText) ?? 0
        let m = Int(minutesText) ?? 0
        let s = Double(secondsText) ?? 0.0
        let totalSeconds = Double(h * 3600 + m * 60) + s
        guard totalSeconds > 0 else {
            resultText = "有効な時間を入力してください"
            return
        }
        let pacePerKm = totalSeconds / dist
        let paceFormatted = TimeFormatter.formatTimeWithFraction(pacePerKm)
        resultText = "ペース: \(paceFormatted) /km"
        computedPaceSecondsPerKm = pacePerKm
        adjustLapPreset(raceType: selectedRaceType, distanceKm: dist)
        updateAutoLaps(totalDistanceKm: dist)
    }
    
    /// 時間を計算
    func calculateTime() {
        guard let dist = Double(distance), dist > 0 else {
            resultText = "有効な距離を入力してください"
            autoLaps = []
            computedPaceSecondsPerKm = nil
            return
        }
        guard dist <= 1000 else {
            resultText = "距離が範囲外です（1000km以下）"
            autoLaps = []
            computedPaceSecondsPerKm = nil
            return
        }
        let paceMin = Int(paceMinutesText) ?? 0
        let paceSec = Double(paceSecondsText) ?? 0.0
        let paceSecondsPerKm = Double(paceMin * 60) + paceSec
        computedPaceSecondsPerKm = paceSecondsPerKm
        guard paceSecondsPerKm > 0 else {
            resultText = "有効なペースを入力してください"
            autoLaps = []
            return
        }
        let totalSeconds = paceSecondsPerKm * dist
        let timeString = TimeFormatter.formatTimeWithFraction(totalSeconds)
        resultText = "タイム: \(timeString)"
        adjustLapPreset(raceType: selectedRaceType, distanceKm: dist)
        updateAutoLaps(totalDistanceKm: dist)
    }
    
    /// 距離を計算
    func calculateDistance() {
        let h = Int(hoursText) ?? 0
        let m = Int(minutesText) ?? 0
        let s = Double(secondsText) ?? 0.0
        let totalSeconds = Double(h * 3600 + m * 60) + s
        guard totalSeconds > 0 else {
            resultText = "有効な時間を入力してください"
            autoLaps = []
            computedPaceSecondsPerKm = nil
            return
        }
        let paceMin = Int(paceMinutesText) ?? 0
        let paceSec = Double(paceSecondsText) ?? 0.0
        let paceSecondsPerKm = Double(paceMin * 60) + paceSec
        computedPaceSecondsPerKm = paceSecondsPerKm
        guard paceSecondsPerKm > 0 else {
            resultText = "有効なペースを入力してください"
            autoLaps = []
            return
        }
        let calculatedDistance = totalSeconds / paceSecondsPerKm
        guard calculatedDistance > 0 && calculatedDistance < 1000 else {
            resultText = "計算結果が範囲外です"
            autoLaps = []
            return
        }
        resultText = String(format: "距離: %.2f km", calculatedDistance)
        adjustLapPreset(raceType: selectedRaceType, distanceKm: calculatedDistance)
        updateAutoLaps(totalDistanceKm: calculatedDistance)
    }
    
    /// 計算を実行
    @MainActor
    func calculate() {
        switch mode {
        case .calculatePace:
            calculatePace()
        case .calculateTime:
            calculateTime()
        case .calculateDistance:
            calculateDistance()
        }
    }
    
    /// リセット
    func reset() {
        selectedDistanceId = nil
        distance = ""
        hoursText = ""
        minutesText = ""
        secondsText = ""
        paceMinutesText = ""
        paceSecondsText = ""
        resultText = ""
        autoLaps = []
        computedPaceSecondsPerKm = nil
        selectedRaceType = nil
        selectedDistanceName = nil
    }
    
    private func lapDistanceKm() -> Double? {
        switch lapPreset {
        case "400m": return 0.4
        case "1000m": return 1.0
        case "1km": return 1.0
        case "5km": return 5.0
        case "custom":
            if let v = Double(customLapText), v > 0 {
                // 単位がmの場合はkmに変換
                return customLapUnit == "m" ? v / 1000.0 : v
            }
            return nil
        default: return nil
        }
    }
    
    private func updateAutoLaps(totalDistanceKm: Double) {
        guard let d = lapDistanceKm(), d > 0, d <= totalDistanceKm else { 
            autoLaps = [] 
            return 
        }
        var remain = totalDistanceKm
        var laps: [Double] = []
        let maxLaps = 1000 // 無限ループ防止
        var count = 0
        while remain > 0.0001 && count < maxLaps {
            let seg = min(d, remain)
            laps.append(seg)
            remain -= seg
            count += 1
        }
        autoLaps = laps
    }
    
    func updateAutoLapsIfNeeded() {
        guard let dist = Double(distance), dist > 0 else {
            autoLaps = []
            return
        }
        guard let _ = computedPaceSecondsPerKm else {
            autoLaps = []
            return
        }
        updateAutoLaps(totalDistanceKm: dist)
    }
    
    /// 距離・種別に応じてラッププリセットとカスタム単位を自動調整
    private func adjustLapPreset(raceType: RaceType?, distanceKm: Double?) {
        let dist = distanceKm ?? Double(distance) ?? 0
        // 10km未満ではカスタム単位をmに、10km以上ではkmに
        customLapUnit = dist < 10.0 ? "m" : "km"
        
        // カスタムの場合はプリセット変更しない
        guard lapPreset != "custom" else { return }
        
        let allowedPresets: [String]
        if let type = raceType {
            switch type {
            case .track:
                allowedPresets = ["400m", "1000m"]
            case .road:
                allowedPresets = ["1km", "5km"]
            case .other:
                allowedPresets = dist >= 10.0 ? ["1km", "5km"] : ["400m", "1000m"]
            }
        } else {
            allowedPresets = dist >= 10.0 ? ["1km", "5km"] : ["400m", "1000m"]
        }
        
        if !allowedPresets.contains(lapPreset) {
            lapPreset = allowedPresets.first ?? "custom"
        }
    }

    /// 距離テキスト変更時の処理（手入力時にプリセット/単位を調整）
    func handleDistanceInputChange() {
        // applyDistanceSelection実行中は処理をスキップ（二重実行防止）
        guard !isApplyingDistanceSelection else { return }
        let dist = Double(distance)
        adjustLapPreset(raceType: selectedRaceType, distanceKm: dist)
    }
    
    /// 種目選択時に関連状態を更新
    func applyDistanceSelection(_ distance: RaceDistance) {
        isApplyingDistanceSelection = true
        selectedDistanceId = distance.persistentModelID
        selectedRaceType = distance.raceType
        selectedDistanceName = distance.name
        self.distance = String(format: "%.3f", distance.distanceKm)
        adjustLapPreset(raceType: distance.raceType, distanceKm: distance.distanceKm)
        updateAutoLapsIfNeeded()
        isApplyingDistanceSelection = false
    }
    
    /// 種目選択を解除したときのリセット
    func clearSelectedDistance() {
        selectedDistanceId = nil
        selectedRaceType = nil
        selectedDistanceName = nil
    }
}

// ラッププリセットの選択肢を距離に応じて変更
extension PaceCalculatorViewModel {
    func availableLapPresets() -> [String] {
        let dist = Double(distance) ?? 0
        if let type = selectedRaceType {
            switch type {
            case .track:
                return ["400m", "1000m", "custom"]
            case .road:
                return ["1km", "5km", "custom"]
            case .other:
                return dist >= 10.0 ? ["1km", "5km", "custom"] : ["400m", "1000m", "custom"]
            }
        }
        return dist >= 10.0 ? ["1km", "5km", "custom"] : ["400m", "1000m", "custom"]
    }
    
    /// UI表示用の種目ラベル
    var selectedDistanceLabel: String? {
        guard let type = selectedRaceType, let name = selectedDistanceName else { return nil }
        return "種目  \(type.displayName)  \(name)"
    }
}

import Foundation

enum TimeInputNormalizer {
    /// 入力テキスト（時・分・秒）を正規化して返す
    static func normalize(hoursText: String, minutesText: String, secondsText: String) -> (hours: String, minutes: String, seconds: String) {
        let h = Int(hoursText) ?? 0
        let m = Int(minutesText) ?? 0
        let s = Double(secondsText) ?? 0.0

        let addMinutes = Int(s / 60)
        let remainingSeconds = s.truncatingRemainder(dividingBy: 60)

        var totalMinutes = m + addMinutes
        let addHours = totalMinutes / 60
        totalMinutes = totalMinutes % 60
        let totalHours = h + addHours

        let hoursOut = String(totalHours)
        let minutesOut = String(totalMinutes)
        let secondsOut = remainingSeconds == 0.0 ? "0" : String(format: "%.2f", remainingSeconds)
        return (hoursOut, minutesOut, secondsOut)
    }
}

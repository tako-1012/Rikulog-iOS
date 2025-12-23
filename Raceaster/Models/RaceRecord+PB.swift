import Foundation

extension RaceRecord {
    /// 秒数を mm:ss 形式に変換
    var formattedTime: String {
        let total = Int(totalTime.rounded())
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

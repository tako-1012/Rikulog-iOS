import Foundation

/// 時間フォーマットのユーティリティクラス
/// Int型の秒数とhh:mm:ss形式の文字列を相互変換する
struct TimeFormatter {
    
    /// 秒数をhh:mm:ss形式の文字列に変換
    /// - Parameter seconds: 秒数
    /// - Returns: hh:mm:ss形式の文字列
    static func formatTime(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        } else {
            return String(format: "%d:%02d", minutes, secs)
        }
    }
    
    /// 秒数をmm:ss形式の文字列に変換（ペース表示用）
    /// - Parameter seconds: 秒数
    /// - Returns: mm:ss形式の文字列
    static func formatPace(_ seconds: Double) -> String {
        let totalSeconds = Int(seconds.rounded())
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%d:%02d", minutes, secs)
    }
    
    /// 秒数をmm:ss.ss形式の文字列に変換（PB・レース記録用）
    /// - Parameter seconds: 秒数（Int）
    /// - Returns: mm:ss.ss形式の文字列
    static func formatTimeDecimal(_ seconds: Double) -> String {
        let minutes = Int(seconds / 60)
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        return String(format: "%d:%05.2f", minutes, secs)
    }

    /// レース種目に応じたタイム表示
    /// - Parameters:
    ///   - seconds: 秒数（Double）
    ///   - raceType: 種目（`RaceType`）
    /// - Returns: 種目に合わせた表示（ロードは整数秒、トラックは小数点を含む表示）
    static func formatTime(_ seconds: Double, for raceType: RaceType) -> String {
        switch raceType {
        case .road:
            // ロードは整数秒で表示（保存時は切り上げ済みだが念のため切り上げてから表示）
            let totalSeconds = Int(ceil(seconds))
            let hours = totalSeconds / 3600
            let minutes = (totalSeconds % 3600) / 60
            let secs = totalSeconds % 60
            if hours > 0 {
                return String(format: "%d:%02d:%02d", hours, minutes, secs)
            } else {
                return String(format: "%d:%02d", minutes, secs)
            }

        case .track, .other:
            // トラックは小数点まで表示（既存の小数保持を尊重）
            return formatTimeWithFraction(seconds)
        case .field:
            // フィールド種目はタイム表示を使用しない
            return "-"
        }
    }

    /// 秒数をhh:mm:ss.ss もしくは mm:ss.ss に変換（小数も保持）
    /// - Parameter seconds: 秒数（Double、小数点以下対応）
    /// - Returns: hh:mm:ss.ss または mm:ss.ss 形式の文字列
    static func formatTimeWithFraction(_ seconds: Double) -> String {
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        let secs = seconds.truncatingRemainder(dividingBy: 60)
        if hours > 0 {
            return String(format: "%d:%02d:%05.2f", hours, minutes, secs)
        } else {
            return String(format: "%d:%05.2f", minutes, secs)
        }
    }
    
    /// hh:mm:ss形式の文字列を秒数に変換
    /// - Parameter timeString: hh:mm:ss または mm:ss 形式の文字列
    /// - Returns: 秒数。変換できない場合はnil
    static func parseTime(_ timeString: String) -> Int? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        
        switch components.count {
        case 3: // hh:mm:ss
            guard components[0] >= 0, components[0] < 168, // 最大7日
                  components[1] >= 0, components[1] < 60,
                  components[2] >= 0, components[2] < 60 else {
                return nil
            }
            let totalSeconds = components[0] * 3600 + components[1] * 60 + components[2]
            guard totalSeconds < 604800 else { return nil } // 7日（604800秒）以内
            return totalSeconds
            
        case 2: // mm:ss
            guard components[0] >= 0, components[0] < 10080, // 最大7日分の分
                  components[1] >= 0, components[1] < 60 else {
                return nil
            }
            let totalSeconds = components[0] * 60 + components[1]
            guard totalSeconds < 604800 else { return nil }
            return totalSeconds
            
        case 1: // ss
            guard components[0] >= 0, components[0] < 604800 else {
                return nil
            }
            return components[0]
            
        default:
            return nil
        }
    }
    
    /// 時間、分、秒を個別に指定して秒数に変換
    /// - Parameters:
    ///   - hours: 時間
    ///   - minutes: 分
    ///   - seconds: 秒
    /// - Returns: 合計秒数
    static func toSeconds(hours: Int, minutes: Int, seconds: Int) -> Int {
        return hours * 3600 + minutes * 60 + seconds
    }
    
    /// 秒数を時間、分、秒に分解
    /// - Parameter totalSeconds: 合計秒数
    /// - Returns: (時間, 分, 秒)のタプル
    static func breakdown(_ totalSeconds: Int) -> (hours: Int, minutes: Int, seconds: Int) {
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return (hours, minutes, seconds)
    }
}

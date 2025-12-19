import Foundation

/// 時間フォーマットのユーティリティクラス
/// Int型の秒数とhh:mm:ss形式の文字列を相互変換する
struct TimeFormatter {
    
    /// 秒数をhh:mm:ss形式の文字列に変換
    /// - Parameter seconds: 秒数
    /// - Returns: hh:mm:ss形式の文字列
    static func formatTime(_ seconds: Int) -> String {
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        let secs = seconds % 60
        
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
    
    /// hh:mm:ss形式の文字列を秒数に変換
    /// - Parameter timeString: hh:mm:ss または mm:ss 形式の文字列
    /// - Returns: 秒数。変換できない場合はnil
    static func parseTime(_ timeString: String) -> Int? {
        let components = timeString.split(separator: ":").compactMap { Int($0) }
        
        switch components.count {
        case 3: // hh:mm:ss
            guard components[0] >= 0, components[1] >= 0, components[1] < 60,
                  components[2] >= 0, components[2] < 60 else {
                return nil
            }
            return components[0] * 3600 + components[1] * 60 + components[2]
            
        case 2: // mm:ss
            guard components[0] >= 0, components[1] >= 0, components[1] < 60 else {
                return nil
            }
            return components[0] * 60 + components[1]
            
        case 1: // ss
            guard components[0] >= 0 else {
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

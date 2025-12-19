import Foundation

/// VDOT（走力指標）を計算するユーティリティクラス
/// ダニエルズのランニング・フォーミュラに基づく近似計算を行う
struct VDOTCalculator {
    
    /// トレーニングゾーンの種類
    enum TrainingZone {
        case easy
        case marathon
        case threshold
        case interval
        case repetition
    }
    
    /// 距離（km）とタイム（秒）からVDOTを計算
    /// - Parameters:
    ///   - distanceKm: 距離（km）
    ///   - timeSeconds: タイム（秒）
    /// - Returns: VDOT値
    static func calculateVDOT(distanceKm: Double, timeSeconds: Int) -> Double {
        // 距離をメートルに変換
        let distanceMeters = distanceKm * 1000.0
        let timeMinutes = Double(timeSeconds) / 60.0
        
        // 酸素摂取量の計算（簡易版）
        // VO2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity^2
        let velocity = distanceMeters / timeMinutes // m/min
        let vo2 = -4.60 + 0.182258 * velocity + 0.000104 * velocity * velocity
        
        // パフォーマンスファクターの計算
        // %VO2max = 0.8 + 0.1894393 * e^(-0.012778 * time) + 0.2989558 * e^(-0.1932605 * time)
        let percentVO2Max = 0.8 + 0.1894393 * exp(-0.012778 * timeMinutes) + 0.2989558 * exp(-0.1932605 * timeMinutes)
        
        // VDOT = VO2 / %VO2max
        let vdot = vo2 / percentVO2Max
        
        return max(vdot, 0)
    }
    
    /// VDOTからトレーニングペース（秒/km）を計算
    /// - Parameters:
    ///   - vdot: VDOT値
    ///   - zone: トレーニングゾーン
    /// - Returns: ペース（秒/km）
    static func trainingPace(vdot: Double, zone: TrainingZone) -> Double {
        // VDOT値から各ゾーンのペースを推定（簡易版）
        // 実際のダニエルズの表に基づいた近似式
        
        switch zone {
        case .easy:
            // Easy: VDOT × 0.65-0.79
            let vo2Percent = 0.70
            return calculatePaceForVO2(vdot: vdot, vo2Percent: vo2Percent)
            
        case .marathon:
            // Marathon: VDOT × 0.84-0.88
            let vo2Percent = 0.86
            return calculatePaceForVO2(vdot: vdot, vo2Percent: vo2Percent)
            
        case .threshold:
            // Threshold: VDOT × 0.88-0.92
            let vo2Percent = 0.90
            return calculatePaceForVO2(vdot: vdot, vo2Percent: vo2Percent)
            
        case .interval:
            // Interval: VDOT × 0.98-1.00
            let vo2Percent = 0.99
            return calculatePaceForVO2(vdot: vdot, vo2Percent: vo2Percent)
            
        case .repetition:
            // Repetition: VDOT × 1.05-1.10
            let vo2Percent = 1.07
            return calculatePaceForVO2(vdot: vdot, vo2Percent: vo2Percent)
        }
    }
    
    /// VO2比率からペースを計算（内部使用）
    private static func calculatePaceForVO2(vdot: Double, vo2Percent: Double) -> Double {
        let vo2 = vdot * vo2Percent
        
        // VO2からベロシティを逆算
        // velocity = (-0.182258 + sqrt(0.182258^2 + 4 * 0.000104 * (vo2 + 4.60))) / (2 * 0.000104)
        let a = 0.000104
        let b = 0.182258
        let c = -(vo2 + 4.60)
        
        let discriminant = b * b - 4 * a * c
        guard discriminant >= 0 else { return 300.0 } // デフォルト値（5分/km）
        
        let velocity = (-b + sqrt(discriminant)) / (2 * a)
        
        // ベロシティ（m/min）からペース（秒/km）に変換
        let paceMinPerKm = 1000.0 / velocity
        let paceSecPerKm = paceMinPerKm * 60.0
        
        return paceSecPerKm
    }
    
    /// すべてのトレーニングゾーンのペースを計算
    /// - Parameter vdot: VDOT値
    /// - Returns: 各ゾーンのペース（秒/km）の辞書
    static func allTrainingPaces(vdot: Double) -> [TrainingZone: Double] {
        return [
            .easy: trainingPace(vdot: vdot, zone: .easy),
            .marathon: trainingPace(vdot: vdot, zone: .marathon),
            .threshold: trainingPace(vdot: vdot, zone: .threshold),
            .interval: trainingPace(vdot: vdot, zone: .interval),
            .repetition: trainingPace(vdot: vdot, zone: .repetition)
        ]
    }
}

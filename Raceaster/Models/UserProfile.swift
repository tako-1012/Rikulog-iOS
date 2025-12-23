import Foundation
import SwiftData

/// ユーザープロフィール情報
@Model
final class UserProfile {
    /// 名前
    var name: String = "ランナー"
    
    /// 生年月日
    var birthDate: Date?
    
    /// 身長（cm）
    var height: Double?
    
    /// 体重（kg）
    var weight: Double?
    
    /// 体脂肪率（%）
    var bodyFatPercentage: Double?
    
    /// 所属クラブ
    var club: String = ""

    /// シーズン開始月 (1-12)。デフォルトは4月。
    var seasonStartMonth: Int = 4

    /// シーズン終了月 (1-12)。デフォルトは3月。
    var seasonEndMonth: Int = 3
    
    /// 作成日時
    var createdAt: Date = Date()
    
    /// BMI計算プロパティ
    var bmi: Double? {
        guard let h = height, let w = weight, h >= 10, h < 300, w > 0, w < 500 else { return nil }
        let heightInMeters = h / 100.0
        guard heightInMeters > 0.1 else { return nil } // 10cm未満は異常値
        let calculatedBMI = w / (heightInMeters * heightInMeters)
        // BMI値の妥当性チェック（5-100の範囲）
        guard calculatedBMI >= 5 && calculatedBMI <= 100 else { return nil }
        return calculatedBMI
    }
    
    /// 年齢計算プロパティ
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        // 未来の生年月日をチェック
        guard birthDate <= Date() else { return nil }
        let calendar = Calendar.current
        let ageComponents = calendar.dateComponents([.year], from: birthDate, to: Date())
        guard let calculatedAge = ageComponents.year, calculatedAge >= 0, calculatedAge < 150 else { return nil }
        return calculatedAge
    }
    
    init(
        name: String = "ランナー",
        birthDate: Date? = nil,
        height: Double? = nil,
        weight: Double? = nil,
        bodyFatPercentage: Double? = nil,
        club: String = "",
        createdAt: Date = Date(),
        seasonStartMonth: Int = 4,
        seasonEndMonth: Int = 3
    ) {
        self.name = name
        self.birthDate = birthDate
        self.height = height
        self.weight = weight
        self.bodyFatPercentage = bodyFatPercentage
        self.club = club
        self.createdAt = createdAt
        self.seasonStartMonth = seasonStartMonth
        self.seasonEndMonth = seasonEndMonth
    }
}

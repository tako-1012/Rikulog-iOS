import Foundation

/// ラップ入力用の一時データ構造体（フォーム入力・UI状態管理用）
/// 永続モデルは `Lap`（SwiftData @Model）を使用する
struct LapInput: Identifiable {
    let id: UUID
    var distance: Double
    var time: Double

    init(id: UUID = UUID(), distance: Double, time: Double) {
        self.id = id
        self.distance = distance
        self.time = time
    }
}

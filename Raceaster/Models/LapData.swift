import Foundation

/// ラップデータ構造体
struct LapData: Identifiable {
    let id: UUID
    var distance: Double
    var time: Double
    
    init(id: UUID = UUID(), distance: Double, time: Double) {
        self.id = id
        self.distance = distance
        self.time = time
    }
}

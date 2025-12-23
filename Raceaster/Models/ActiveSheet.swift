import Foundation

/// シート表示を管理するenum
enum ActiveSheet: Identifiable, Equatable {
    case addDistance
    case addLap
    case editLap(Int)
    
    var id: String {
        switch self {
        case .addDistance: return "addDistance"
        case .addLap: return "addLap"
        case .editLap(let idx): return "editLap_\(idx)"
        }
    }
}

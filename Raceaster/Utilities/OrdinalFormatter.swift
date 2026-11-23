import Foundation

func ordinalString(for rank: Int) -> String {
    let formatter = NumberFormatter()
    formatter.numberStyle = .ordinal
    return formatter.string(from: NSNumber(value: rank)) ?? "\(rank)"
}

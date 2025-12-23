import SwiftUI

// 初期値が "0" / "0.0" のとき、最初のタップでクリアするモディファイア
struct ClearZeroOnFocus: ViewModifier {
    @Binding var text: String
    @State private var didClear = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(TapGesture().onEnded {
                clearIfZero()
            })
    }

    private func clearIfZero() {
        guard !didClear else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if isZeroLike(trimmed) {
            text = ""
            didClear = true
        }
    }

    private func isZeroLike(_ s: String) -> Bool {
        // "0", "00", "000", "0.", "0.0", "0.00" などをゼロ相当と判定
        if s.allSatisfy({ $0 == "0" || $0 == "." }) {
            // すべてが 0 と . のみの場合、かつ数値に変換して 0 相当
            let normalized = s.replacingOccurrences(of: ".", with: "")
            return !normalized.isEmpty
        }
        if let v = Double(s) { return v == 0 }
        return false
    }
}

extension View {
    func clearZeroOnFocus(_ text: Binding<String>) -> some View {
        modifier(ClearZeroOnFocus(text: text))
    }
}

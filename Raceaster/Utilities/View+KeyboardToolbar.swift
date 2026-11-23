import SwiftUI

extension View {
    // 修正版: SwiftUI標準の仕組みを使って「完了」ボタンを設置します。
    // これなら浮いたり、変な青いボタンになったりしません。
    
    func keyboardDoneToolbar(action: @escaping () -> Void = {}) -> some View {
        self.toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer() // ボタンを右端に寄せる
                Button("keyboard.done") {
                    // 1. 指定されたアクションを実行（もしあれば）
                    action()
                    // 2. キーボードを閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
                // シンプルなスタイルに戻す（複雑な装飾はレイアウトinvalidationsを誘発する可能性がある）
                .buttonStyle(.plain)
                .foregroundColor(.primary)
            }
        }
    }
    
    // 互換性のためのエイリアス（他の名前で呼んでいる箇所用）
    func keyboardToolbar(action: @escaping () -> Void = {}) -> some View {
        keyboardDoneToolbar(action: action)
    }
    
    func addDoneButton() -> some View {
        keyboardDoneToolbar()
    }
}
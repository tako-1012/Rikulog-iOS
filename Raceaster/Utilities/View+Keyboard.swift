import SwiftUI

extension View {
    /// 背景タップでキーボードを閉じる（simultaneousGesture版）
    func hideKeyboardOnTap() -> some View {
        self.simultaneousGesture(
            TapGesture()
                .onEnded { _ in
                    let keyWindow = UIApplication.shared.connectedScenes
                        .compactMap { $0 as? UIWindowScene }
                        .flatMap { $0.windows }
                        .first { $0.isKeyWindow }

                    keyWindow?.endEditing(true)
                }
        )
    }
}

import UIKit
import SwiftUI

extension UIApplication {
    /// ウィンドウ全体にタップジェスチャを追加し、タップ時にキーボードを閉じる
    func enableKeyboardDismissOnTap() {
        guard let window = connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .flatMap({ $0.windows })
            .first(where: { $0.isKeyWindow }) else {
            return
        }
        
        // 重複チェック
        let existingGestures = window.gestureRecognizers ?? []
        let alreadyAdded = existingGestures.contains { gesture in
            gesture is UITapGestureRecognizer &&
            gesture.name == "KeyboardDismissTapGesture"
        }
        
        guard !alreadyAdded else {
            print("ℹ️ Keyboard dismiss gesture already added")
            return
        }
        
        let tapGesture = UITapGestureRecognizer()
        tapGesture.name = "KeyboardDismissTapGesture"
        tapGesture.cancelsTouchesInView = false  // 重要！
        tapGesture.delegate = KeyboardDismissGestureDelegate.shared
        tapGesture.addTarget(KeyboardDismissGestureDelegate.shared, 
                            action: #selector(KeyboardDismissGestureDelegate.dismissKeyboard))
        
        window.addGestureRecognizer(tapGesture)
        print("✅ Keyboard dismiss gesture added")
    }
}

private class KeyboardDismissGestureDelegate: NSObject, UIGestureRecognizerDelegate {
    static let shared = KeyboardDismissGestureDelegate()
    
    @objc func dismissKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                       to: nil, from: nil, for: nil)
    }
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        return true
    }
    

    /// タップを受け取るかどうかの判定（シンプル版）
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                          shouldReceive touch: UITouch) -> Bool {
        // 基本動作: テキスト入力中にフィールドを直接タップした場合はキーボードを閉じない
        guard let view = touch.view else { return true }

        // UITextField / UITextView は直接タップしたら閉じない
        if view is UITextField || view is UITextView { return false }

        // UIControl 系（ボタン、スイッチ等）は操作を優先してキーボードを閉じない
        if view is UIControl { return false }

        // それ以外はタップでキーボードを閉じる
        return true
    }
}

// ヘルパー拡張
private extension UIView {
    func isDescendant(of type: AnyClass) -> Bool {
        var view: UIView? = self
        while let currentView = view {
            if currentView.isKind(of: type) {
                return true
            }
            view = currentView.superview
        }
        return false
    }
}

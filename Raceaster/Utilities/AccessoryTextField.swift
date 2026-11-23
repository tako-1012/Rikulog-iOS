import UIKit
import SwiftUI

// MARK: - 1. Internal UIKit TextField
// キーボードの「完了」ボタンを表示する機能の本体
final class AccessoryTextField_Internal: UITextField {

    // ツールバーを保持しておき、必要な時に再利用できるようにする
    var toolbar: UIToolbar?

    override init(frame: CGRect) {
        super.init(frame: frame)
        setupToolbar()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupToolbar()
    }

    private func setupToolbar() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()

        // 固定高さでシンプルなツールバーにして、頻繁なレイアウト変化を防ぐ
        toolbar.isTranslucent = true
        // サイズを明示してレイアウトループの原因になりにくくする
        var tbFrame = toolbar.frame
        if tbFrame.height == 0 { tbFrame.size.height = 44 }
        toolbar.frame = tbFrame

        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        // ✅ 修正：明示的な「完了」タイトルを表示し、iOSの警告に配慮しつつ完了ボタンを復活
        let doneButton = UIBarButtonItem(title: String(localized: "keyboard.done"), style: .plain, target: self, action: #selector(doneButtonTapped))
        doneButton.accessibilityLabel = String(localized: "keyboard.done")

        toolbar.items = [flexSpace, doneButton]
        self.toolbar = toolbar
        self.inputAccessoryView = toolbar
    }

    @objc private func doneButtonTapped() {
        self.resignFirstResponder()
    }
}

// MARK: - 2. SwiftUI Wrapper
// アプリ全体からの呼び出し（showAccessory含む）に完全対応したアダプター
struct AccessoryTextField: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var keyboardType: UIKeyboardType
    var textAlignment: NSTextAlignment
    var isFirstResponder: Binding<Bool>?
    var showAccessory: Bool // ← これを追加してエラーを解消

    // ---------------------------------------------------------
    // イニシャライザ (エラーの原因だった showAccessory を追加)
    // ---------------------------------------------------------

    // パターンA: AccessoryTextField("プレースホルダー", text: $text)
    init(_ placeholder: String, 
         text: Binding<String>, 
         keyboardType: UIKeyboardType = .default, 
         isFirstResponder: Binding<Bool>? = nil,
         showAccessory: Bool = true) { // 引数を追加
        self.placeholder = placeholder
        self._text = text
        self.keyboardType = keyboardType
        self.textAlignment = .left
        self.isFirstResponder = isFirstResponder
        self.showAccessory = showAccessory
    }

    // パターンB: 名前付き引数 init(text: ..., placeholder: ...)
    init(text: Binding<String>, 
         placeholder: String = "", 
         keyboardType: UIKeyboardType = .default, 
         isFirstResponder: Binding<Bool>? = nil,
         showAccessory: Bool = true) { // 引数を追加
        self._text = text
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.textAlignment = .left
        self.isFirstResponder = isFirstResponder
        self.showAccessory = showAccessory
    }
    
    // ---------------------------------------------------------
    // UIViewRepresentable implementation
    // ---------------------------------------------------------

    func makeUIView(context: Context) -> AccessoryTextField_Internal {
        let tf = AccessoryTextField_Internal(frame: .zero)
        tf.borderStyle = .roundedRect
        tf.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        
        // デリゲート設定
        tf.delegate = context.coordinator
        tf.addTarget(context.coordinator, action: #selector(Coordinator.editingChanged(_:)), for: .editingChanged)
        
        // 初回表示設定
        updateAccessoryView(tf)
        
        return tf
    }

    func updateUIView(_ uiView: AccessoryTextField_Internal, context: Context) {
        uiView.placeholder = placeholder
        uiView.keyboardType = keyboardType
        uiView.textAlignment = textAlignment
        
        if uiView.text != text {
            uiView.text = text
        }

        // ツールバーの表示/非表示を更新
        updateAccessoryView(uiView)

        // フォーカス制御
        if let isFirstResponder = isFirstResponder {
            if isFirstResponder.wrappedValue && !uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.becomeFirstResponder() }
            } else if !isFirstResponder.wrappedValue && uiView.isFirstResponder {
                DispatchQueue.main.async { uiView.resignFirstResponder() }
            }
        }
    }
    
    // ツールバーの付け外しを行うヘルパー
    private func updateAccessoryView(_ tf: AccessoryTextField_Internal) {
        if showAccessory {
            tf.inputAccessoryView = tf.toolbar
        } else {
            tf.inputAccessoryView = nil
        }
    }

    // ---------------------------------------------------------
    // Modifiers
    // ---------------------------------------------------------

    func keyboardType(_ type: UIKeyboardType) -> AccessoryTextField {
        var view = self
        view.keyboardType = type
        return view
    }

    func multilineTextAlignment(_ alignment: TextAlignment) -> AccessoryTextField {
        var view = self
        switch alignment {
        case .center: view.textAlignment = .center
        case .trailing: view.textAlignment = .right
        default: view.textAlignment = .left
        }
        return view
    }

    // ---------------------------------------------------------
    // Coordinator
    // ---------------------------------------------------------
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UITextFieldDelegate {
        var parent: AccessoryTextField

        init(_ parent: AccessoryTextField) {
            self.parent = parent
        }

        @objc func editingChanged(_ sender: UITextField) {
            parent.text = sender.text ?? ""
        }
        
        func textFieldDidBeginEditing(_ textField: UITextField) {
            parent.isFirstResponder?.wrappedValue = true
        }
        
        func textFieldDidEndEditing(_ textField: UITextField) {
            parent.isFirstResponder?.wrappedValue = false
        }
        
        func textFieldShouldReturn(_ textField: UITextField) -> Bool {
            textField.resignFirstResponder()
            return true
        }
    }
}
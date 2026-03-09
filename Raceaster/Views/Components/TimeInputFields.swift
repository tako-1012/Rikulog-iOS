import SwiftUI

/// 時間入力（時・分・秒）を統一する共通コンポーネント
struct TimeInputFields: View {
    @Binding var hoursText: String
    @Binding var minutesText: String
    @Binding var secondsText: String

    // フォーカス管理（親と連携）
    @FocusState var focusedField: FocusedField?
    // Optional simple focus binding (使わないので無視します)
    var simpleFocusBinding: Binding<Bool>? = nil

    enum FocusedField { case hours, minutes, seconds }

    /// フォーカスが外れたタイミングで正規化を行う
    var onNormalize: (() -> Void)?
    // Whether to enable AccessoryTextField's inputAccessoryView Done button.
    var accessoryEnabled: Bool = true
    // Whether to show the hours field (false for pace input)
    var showHours: Bool = true

    var body: some View {
        ZStack {
            // 背景タップでキーボードを閉じる
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    // 強制的にキーボードを閉じる
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    focusedField = nil
                    onNormalize?()
                }

            HStack(spacing: 8) {
                if showHours {
                    VStack(spacing: 4) {
                        AccessoryTextField(text: $hoursText, placeholder: "0", keyboardType: .numberPad, isFirstResponder: nil, showAccessory: accessoryEnabled)
                            .multilineTextAlignment(.center)
                            .frame(width: 70, height: 44)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(8)
                        Text("時間").font(.caption).foregroundStyle(.secondary)
                    }
                    
                    Text(":").font(.title2).padding(.bottom, 20)
                }
                
                VStack(spacing: 4) {
                    AccessoryTextField(text: $minutesText, placeholder: "0", keyboardType: .numberPad, isFirstResponder: nil, showAccessory: accessoryEnabled)
                        .multilineTextAlignment(.center)
                        .frame(width: 70, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("分").font(.caption).foregroundStyle(.secondary)
                }
                
                Text(":").font(.title2).padding(.bottom, 20)
                
                VStack(spacing: 4) {
                    AccessoryTextField(text: $secondsText, placeholder: "0.0", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: accessoryEnabled)
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("秒").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
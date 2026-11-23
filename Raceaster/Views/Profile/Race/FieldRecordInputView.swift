import SwiftUI
import Foundation

// MARK: - 試技データ構造体

/// 水平跳躍・投擲の1試技
struct FieldAttempt: Identifiable, Codable {
    var id: UUID = UUID()
    var result: Double   // 記録（m）。ファウル時は 0
    var isFoul: Bool

    init(result: Double = 0, isFoul: Bool = false) {
        self.result = result
        self.isFoul = isFoul
    }
}

/// 垂直跳躍（走高跳・棒高跳）の高さごとの試技
struct FieldHeightAttempt: Identifiable, Codable {
    var id: UUID = UUID()
    var height: Double       // バーの高さ（m）
    var results: [String]    // "o"=成功 / "x"=失敗 / "-"=パス

    init(height: Double, results: [String] = []) {
        self.height = height
        self.results = results
    }
}

/// JSON シリアライズ用コンテナ
struct FieldAttemptData: Codable {
    var attempts: [FieldAttempt]?
    var heightAttempts: [FieldHeightAttempt]?
}

// MARK: - JSONヘルパー

enum FieldAttemptJSON {
    static func encode(attempts: [FieldAttempt]) -> String? {
        let data = FieldAttemptData(attempts: attempts)
        return try? String(data: JSONEncoder().encode(data), encoding: .utf8)
    }

    static func encode(heightAttempts: [FieldHeightAttempt]) -> String? {
        let data = FieldAttemptData(heightAttempts: heightAttempts)
        return try? String(data: JSONEncoder().encode(data), encoding: .utf8)
    }

    static func decodeAttempts(from json: String?) -> [FieldAttempt] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        do {
            let decoded = try JSONDecoder().decode(FieldAttemptData.self, from: data)
            return decoded.attempts ?? []
        } catch {
            print("[FieldAttemptJSON] decodeAttempts failed: \(error)")
            return []
        }
    }

    static func decodeHeightAttempts(from json: String?) -> [FieldHeightAttempt] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        do {
            let decoded = try JSONDecoder().decode(FieldAttemptData.self, from: data)
            return decoded.heightAttempts ?? []
        } catch {
            print("[FieldAttemptJSON] decodeHeightAttempts failed: \(error)")
            return []
        }
    }
}

// MARK: - 記録フォーマットユーティリティ

/// フィールド種目の記録を "Xm○○" 形式でフォーマット（例: 7.53 → "7m53"）
func formatFieldRecord(_ meters: Double) -> String {
    guard meters > 0 else { return String(localized: "field.no.record") }
    let m = Int(meters)
    let cm = Int(((meters - Double(m)) * 100).rounded())
    return "\(m)m\(String(format: "%02d", cm))"
}

// MARK: - 水平跳躍・投擲 入力セクション

/// 水平跳躍（走幅跳・三段跳）および投擲種目の入力UI
struct HorizontalFieldSection: View {
    let eventName: String
    let isJumpEvent: Bool  // true = 跳躍（風速あり）、false = 投擲

    @Binding var metersText: String
    @Binding var cmText: String
    @Binding var windSpeedText: String
    @Binding var attempts: [FieldAttempt]

    @FocusState private var focusedField: HorizontalField?

    enum HorizontalField: Hashable {
        case meters, cm, wind, attemptM(Int), attemptCm(Int)
    }

    var body: some View {
        Group {
            bestRecordSection
            attemptsSection
            if isJumpEvent { windSection }
        }
    }

    // MARK: 最高記録
    private var bestRecordSection: some View {
        Section {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    TextField("0", text: $metersText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .meters)
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("m").font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    TextField("00", text: $cmText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .cm)
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("cm").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("field.best.record.section")
        } footer: {
            let meters = Double(metersText) ?? 0
            let cm = Double(cmText) ?? 0
            let total = meters + cm / 100
            if total > 0 {
                Text(String(localized: "field.best.record.section") + ": \(formatFieldRecord(total))")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: 試技結果
    private var attemptsSection: some View {
        Section {
            ForEach(attempts.indices, id: \.self) { i in
                HStack {
                    Text(String(format: String(localized: "field.attempt.label"), i + 1)).foregroundStyle(.secondary).frame(width: 60, alignment: .leading)

                    if attempts[i].isFoul {
                        Text("field.attempt.foul").foregroundStyle(.red).frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        HStack(spacing: 6) {
                            VStack(spacing: 2) {
                                TextField("0", text: Binding(
                                    get: {
                                        let m = Int(attempts[i].result)
                                        return m == 0 && attempts[i].result == 0 ? "" : String(m)
                                    },
                                    set: { newM in
                                        let mVal = Double(newM) ?? 0
                                        let cmVal = ((attempts[i].result - Double(Int(attempts[i].result))) * 100).rounded()
                                        attempts[i].result = mVal + cmVal / 100
                                    }
                                ))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .attemptM(i))
                                .multilineTextAlignment(.center)
                                .frame(width: 60, height: 36)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                Text("m").font(.caption2).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                TextField("00", text: Binding(
                                    get: {
                                        if attempts[i].result == 0 { return "" }
                                        let cm = Int(((attempts[i].result - Double(Int(attempts[i].result))) * 100).rounded())
                                        return cm == 0 ? "" : String(format: "%02d", cm)
                                    },
                                    set: { newCm in
                                        let mVal = Double(Int(attempts[i].result))
                                        let cmVal = Double(newCm) ?? 0
                                        attempts[i].result = mVal + cmVal / 100
                                    }
                                ))
                                .keyboardType(.numberPad)
                                .focused($focusedField, equals: .attemptCm(i))
                                .multilineTextAlignment(.center)
                                .frame(width: 60, height: 36)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                Text("cm").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }

                    Toggle("", isOn: $attempts[i].isFoul)
                        .labelsHidden()
                        .onChange(of: attempts[i].isFoul) { _, foul in
                            if foul { attempts[i].result = 0 }
                        }
                    Image(systemName: attempts[i].isFoul ? "xmark.circle.fill" : "checkmark.circle.fill")
                        .foregroundStyle(attempts[i].isFoul ? .red : .green)
                }
            }
            .onDelete { attempts.remove(atOffsets: $0) }

            if attempts.count < 6 {
                Button {
                    attempts.append(FieldAttempt())
                } label: {
                    Label("field.attempt.add", systemImage: "plus.circle.fill")
                }
            }
        } header: {
            Text("field.attempts.section")
        } footer: {
            Text("field.attempts.footer")
        }
    }

    // MARK: 風速
    private var windSection: some View {
        Section {
            HStack {
                TextField("0.0", text: $windSpeedText)
                    .keyboardType(.decimalPad)
                    .focused($focusedField, equals: .wind)
                Text("m/s")
                    .foregroundStyle(.secondary)

                if let ws = Double(windSpeedText), ws > 2.0 {
                    Text("field.wind.aided.badge")
                        .font(.caption.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange)
                        .cornerRadius(6)
                }
            }
        } header: {
            Text("field.wind.section")
        } footer: {
            Text("field.wind.footer")
        }
    }
}

// MARK: - 垂直跳躍 入力セクション

/// 垂直跳躍（走高跳・棒高跳）の入力UI
struct VerticalFieldSection: View {
    let eventName: String

    @Binding var metersText: String
    @Binding var cmText: String
    @Binding var heightAttempts: [FieldHeightAttempt]

    @FocusState private var focusedField: VerticalField?
    @State private var newHeightText: String = ""

    enum VerticalField: Hashable {
        case meters, cm, newHeight
    }

    var body: some View {
        Group {
            bestRecordSection
            heightAttemptsSection
        }
    }

    // MARK: 最高記録
    private var bestRecordSection: some View {
        Section {
            HStack(spacing: 12) {
                VStack(spacing: 4) {
                    TextField("0", text: $metersText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .meters)
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("m").font(.caption).foregroundStyle(.secondary)
                }
                VStack(spacing: 4) {
                    TextField("00", text: $cmText)
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .cm)
                        .multilineTextAlignment(.center)
                        .frame(width: 80, height: 44)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(8)
                    Text("cm").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.vertical, 4)
        } header: {
            Text("field.best.record.required")
        } footer: {
            let meters = Double(metersText) ?? 0
            let cm = Double(cmText) ?? 0
            let total = meters + cm / 100
            if total > 0 {
                Text("field.current.input.label") + Text(" \(formatFieldRecord(total))")
                    .foregroundStyle(.blue)
            }
        }
    }

    // MARK: 高さ別試技記録
    private var heightAttemptsSection: some View {
        Section {
            ForEach(heightAttempts.indices, id: \.self) { i in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(formatFieldRecord(heightAttempts[i].height))
                            .font(.headline)
                        Spacer()
                        Button(role: .destructive) {
                            heightAttempts.remove(at: i)
                        } label: {
                            Image(systemName: "trash").font(.caption)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                    }
                    HStack(spacing: 8) {
                        ForEach(heightAttempts[i].results.indices, id: \.self) { j in
                            AttemptResultButton(result: $heightAttempts[i].results[j])
                        }
                        if heightAttempts[i].results.count < 3 {
                            Button {
                                heightAttempts[i].results.append("x")
                            } label: {
                                Image(systemName: "plus.circle")
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            // 高さを追加
            HStack(spacing: 12) {
                TextField("field.height.placeholder", text: $newHeightText)
                    .keyboardType(.numberPad)
                    .focused($focusedField, equals: .newHeight)
                    .multilineTextAlignment(.center)
                    .frame(width: 80, height: 44)
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(8)
                Text("cm")
                    .foregroundStyle(.secondary)
                Button("field.height.add.button") {
                    if let cm = Double(newHeightText), cm > 0 {
                        let heightM = cm / 100.0
                        heightAttempts.append(FieldHeightAttempt(height: heightM))
                        heightAttempts.sort { $0.height < $1.height }
                        newHeightText = ""
                        focusedField = nil
                    }
                }
                .buttonStyle(.bordered)
                .disabled(newHeightText.isEmpty)
            }
        } header: {
            Text("field.height.attempts.section")
        } footer: {
            Text("field.height.attempts.footer")
        }
    }
}

// MARK: - 試技結果ボタン（○/×/−）

struct AttemptResultButton: View {
    @Binding var result: String

    private let cycle = ["x", "o", "-"]

    var body: some View {
        Button {
            let idx = cycle.firstIndex(of: result) ?? 0
            result = cycle[(idx + 1) % cycle.count]
        } label: {
            Text(displayText)
                .font(.headline.bold())
                .frame(width: 36, height: 36)
                .background(backgroundColor)
                .foregroundStyle(.white)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var displayText: String {
        switch result {
        case "o": return "○"
        case "-": return "−"
        default:  return "×"
        }
    }

    private var backgroundColor: Color {
        switch result {
        case "o": return .green
        case "-": return .gray
        default:  return .red
        }
    }
}

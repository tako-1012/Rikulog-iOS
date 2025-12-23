import SwiftUI
import SwiftData

struct AddDistanceView: View {
    var onAdd: (RaceDistance) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var name: String = ""
    @State private var distanceValue: String = ""
    @State private var selectedRaceType: RaceType = .track
    @State private var showingError = false
    @State private var errorMessage = ""
    @Query(sort: \RaceDistance.sortOrder) private var existingDistances: [RaceDistance]
    @State private var duplicateCandidate: RaceDistance? = nil
    @State private var showingDuplicateAlert = false
    
    private var isTrack: Bool {
        selectedRaceType == .track
    }
    
    private var unitLabel: String {
        isTrack ? "m" : "km"
    }
    
    var body: some View {
        NavigationStack {
            Form {
            Section("新しい種目") {
                TextField("種目名", text: $name)
                AccessoryTextField(text: $distanceValue, placeholder: "距離 (\(unitLabel))", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: true)
                
                Picker("種別", selection: $selectedRaceType) {
                    Text("トラック").tag(RaceType.track)
                    Text("ロード").tag(RaceType.road)
                    Text("その他").tag(RaceType.other)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedRaceType) { _, new in
                    distanceValue = ""
                }
            }
            }
            .navigationTitle("種目を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        guard !name.isEmpty, name.count <= 50 else {
                            errorMessage = "種目名を入力してください（50文字以内）"
                            showingError = true
                            return
                        }
                        guard let value = Double(distanceValue), value > 0 else {
                            errorMessage = "有効な距離を入力してください"
                            showingError = true
                            return
                        }
                        
                        let km = isTrack ? value / 1000 : value
                        guard km > 0, km <= 1000 else {
                            let maxValue = isTrack ? "1000000m" : "1000km"
                            errorMessage = "有効な距離を入力してください（0より大きく\(maxValue)以下）"
                            showingError = true
                            return
                        }
                        
                        // 重複チェック: 同一種別かつ距離差が 0.001km 未満なら重複とみなす
                        if let existing = existingDistances.first(where: { $0.raceType == selectedRaceType && abs($0.distanceKm - km) < 0.001 }) {
                            duplicateCandidate = existing
                            showingDuplicateAlert = true
                            return
                        }

                        let newDistance = RaceDistance(name: name, distanceKm: km, raceType: selectedRaceType)
                        modelContext.insert(newDistance)
                        do {
                            try modelContext.save()
                            onAdd(newDistance)
                            dismiss()
                        } catch {
                            errorMessage = "保存に失敗しました: \(error.localizedDescription)"
                            showingError = true
                        }
                    }
                }
                // AccessoryTextField provides inputAccessoryView Done button
            }
            .scrollDismissesKeyboard(.interactively)
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("同じ距離の種目が見つかりました", isPresented: $showingDuplicateAlert) {
                Button("既存を選択") {
                    if let dup = duplicateCandidate {
                        onAdd(dup)
                        dismiss()
                    }
                }
                Button("キャンセル", role: .cancel) { }
            } message: {
                Text(duplicateCandidate.map { "\($0.name) が既に存在します。既存を選択しますか？" } ?? "同じ距離の種目が既に存在します。")
            }
        }
    }
}

#Preview {
    AddDistanceView { _ in }
}

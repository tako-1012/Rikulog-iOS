import SwiftUI
import SwiftData

/// レース記録追加ビュー
struct AddRaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    @State private var raceName: String = ""
    @State private var date: Date = Date()
    @State private var distance: String = ""
    @State private var hours: Int = 0
    @State private var minutes: Int = 0
    @State private var seconds: Int = 0
    @State private var memo: String = ""
    
    @State private var showingError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationStack {
            Form {
                Section("基本情報") {
                    TextField("大会名", text: $raceName)
                    
                    DatePicker("開催日", selection: $date, displayedComponents: .date)
                    
                    HStack {
                        TextField("距離", text: $distance)
                            .keyboardType(.decimalPad)
                        Text("km")
                    }
                }
                
                Section("タイム") {
                    HStack {
                        Picker("時", selection: $hours) {
                            ForEach(0..<24, id: \.self) { hour in
                                Text("\(hour)").tag(hour)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        
                        Text(":")
                        
                        Picker("分", selection: $minutes) {
                            ForEach(0..<60, id: \.self) { minute in
                                Text("\(minute)").tag(minute)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                        
                        Text(":")
                        
                        Picker("秒", selection: $seconds) {
                            ForEach(0..<60, id: \.self) { second in
                                Text("\(second)").tag(second)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(width: 80)
                    }
                }
                
                Section("メモ") {
                    TextEditor(text: $memo)
                        .frame(minHeight: 100)
                }
            }
            .navigationTitle("レース記録を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        saveRace()
                    }
                }
            }
            .alert("エラー", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    private func saveRace() {
        // バリデーション
        guard !raceName.isEmpty else {
            errorMessage = "大会名を入力してください"
            showingError = true
            return
        }
        
        guard let dist = Double(distance), dist > 0 else {
            errorMessage = "有効な距離を入力してください"
            showingError = true
            return
        }
        
        let totalSeconds = TimeFormatter.toSeconds(hours: hours, minutes: minutes, seconds: seconds)
        guard totalSeconds > 0 else {
            errorMessage = "有効なタイムを入力してください"
            showingError = true
            return
        }
        
        // RaceRecordの作成と保存
        let newRace = RaceRecord(
            raceName: raceName,
            date: date,
            totalDistance: dist,
            totalTime: totalSeconds,
            memo: memo
        )
        
        modelContext.insert(newRace)
        
        dismiss()
    }
}

#Preview {
    AddRaceView()
        .modelContainer(for: [RaceRecord.self, Lap.self], inMemory: true)
}

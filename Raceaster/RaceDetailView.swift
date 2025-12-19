import SwiftUI

/// レース記録の詳細ビュー
struct RaceDetailView: View {
    let race: RaceRecord
    
    var body: some View {
        List {
            // 基本情報
            Section("基本情報") {
                LabeledContent("大会名", value: race.raceName)
                LabeledContent("開催日", value: race.date, format: .dateTime.year().month().day())
                LabeledContent("距離", value: "\(race.totalDistance, specifier: "%.2f") km")
                LabeledContent("タイム", value: TimeFormatter.formatTime(race.totalTime))
                LabeledContent("平均ペース", value: "\(TimeFormatter.formatPace(race.averagePace)) /km")
            }
            
            // VDOT情報
            Section("走力指標") {
                LabeledContent("VDOT", value: "\(race.vdot, specifier: "%.1f")")
            }
            
            // トレーニングゾーン
            Section("トレーニングペース") {
                let paces = VDOTCalculator.allTrainingPaces(vdot: race.vdot)
                
                if let easyPace = paces[.easy] {
                    LabeledContent("Easy (ジョグ)", value: "\(TimeFormatter.formatPace(easyPace)) /km")
                }
                
                if let marathonPace = paces[.marathon] {
                    LabeledContent("Marathon", value: "\(TimeFormatter.formatPace(marathonPace)) /km")
                }
                
                if let thresholdPace = paces[.threshold] {
                    LabeledContent("Threshold (閾値)", value: "\(TimeFormatter.formatPace(thresholdPace)) /km")
                }
                
                if let intervalPace = paces[.interval] {
                    LabeledContent("Interval", value: "\(TimeFormatter.formatPace(intervalPace)) /km")
                }
                
                if let repetitionPace = paces[.repetition] {
                    LabeledContent("Repetition", value: "\(TimeFormatter.formatPace(repetitionPace)) /km")
                }
            }
            
            // ラップタイム
            if !race.laps.isEmpty {
                Section("ラップタイム") {
                    ForEach(race.laps.sorted(by: { $0.lapNumber < $1.lapNumber })) { lap in
                        HStack {
                            Text("Lap \(lap.lapNumber)")
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text(TimeFormatter.formatTime(lap.time))
                                Text("\(TimeFormatter.formatPace(lap.pace)) /km")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            
            // メモ
            if !race.memo.isEmpty {
                Section("メモ") {
                    Text(race.memo)
                }
            }
        }
        .navigationTitle(race.raceName)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let container = try! ModelContainer(for: RaceRecord.self, Lap.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    
    let race = RaceRecord(
        raceName: "東京マラソン2024",
        date: Date(),
        totalDistance: 42.195,
        totalTime: 10800, // 3時間
        memo: "初めてのフルマラソン"
    )
    container.mainContext.insert(race)
    
    return NavigationStack {
        RaceDetailView(race: race)
    }
    .modelContainer(container)
}

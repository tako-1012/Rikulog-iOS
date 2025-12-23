import SwiftUI
import SwiftData

/// レース記録の詳細ビュー
struct RaceDetailView: View {
    let race: RaceRecord
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceDistance.sortOrder) private var distances: [RaceDistance]
    @State private var navigationPath: NavigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // 基本情報
                Section("基本情報") {
                    LabeledContent("大会名", value: race.raceName)
                    LabeledContent("開催日") {
                        Text(race.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP"))))
                    }
                    LabeledContent("レース種別", value: race.raceType.displayName)
                    LabeledContent("種目", value: distanceDisplayName())
                    LabeledContent("距離", value: String(format: "%.2f km", race.totalDistance))
                    LabeledContent("正式タイム", value: TimeFormatter.formatTimeWithFraction(race.totalTime))
                    LabeledContent("平均ペース", value: "\(TimeFormatter.formatPace(race.averagePace)) /km")
                }
                
                // トラック競技情報
                if race.raceType == .track {
                    Section("競技情報") {
                        if let meetType = race.trackMeetType {
                            LabeledContent("種別", value: meetType.displayName)
                        }
                        if let ranking = race.ranking {
                            LabeledContent("順位", value: "\(ranking)位")
                        }
                        if let group = race.group {
                            LabeledContent("組", value: "\(group)")
                        }
                    }
                }
                
                // VDOT情報
                Section("走力指標") {
                    HStack {
                        Text("VDOT")
                        Spacer()
                        Text(String(format: "%.1f", race.vdot))
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(.blue)
                            .monospacedDigit()
                    }
                }
                
                // ラップタイム
                if !(race.laps ?? []).isEmpty {
                    Section("ラップタイム") {
                        ForEach((race.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber })) { lap in
                            NavigationLink(value: lap) {
                                HStack {
                                    Text("Lap \(lap.lapNumber)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    VStack(alignment: .trailing) {
                                        Text(TimeFormatter.formatTimeWithFraction(lap.time))
                                            .foregroundStyle(.primary)
                                        Text("\(TimeFormatter.formatPace(lap.pace)) /km")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        
                        NavigationLink(
                            destination: AddLapView(
                                onAdd: { newLapDataArray in
                                    let existingLaps = Array(race.laps ?? [])
                                    for lap in existingLaps { modelContext.delete(lap) }
                                    for (index, lapData) in newLapDataArray.enumerated() {
                                        let lap = Lap(
                                            lapNumber: index + 1,
                                            distance: lapData.distance,
                                            time: lapData.time
                                        )
                                        lap.raceRecord = race
                                        modelContext.insert(lap)
                                    }
                                    race.totalTime = newLapDataArray.reduce(0) { $0 + $1.time }
                                    do { try modelContext.save() } catch { }
                                },
                                raceType: race.raceType,
                                totalDistance: race.totalDistance,
                                totalDistanceProvider: { race.totalDistance },
                                initialLaps: (race.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map {
                                    LapData(distance: $0.distance, time: $0.time)
                                }
                            )
                        ) {
                            HStack {
                                Label("ラップを編集", systemImage: "pencil")
                                Spacer()
                            }
                        }
                        .disabled(race.totalDistance <= 0)
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
            .navigationDestination(for: Lap.self) { lap in
                EditLapTimeView(
                    lapNumber: lap.lapNumber,
                    distanceKm: lap.distance,
                    initialSeconds: Int(lap.time),
                    onSave: { newTime in
                        lap.time = Double(newTime)
                        race.totalTime = recalcTotalTime()
                        do {
                            try modelContext.save()
                            navigationPath.removeLast()
                        } catch {
                            // エラーハンドリング
                        }
                    },
                    raceType: race.raceType
                )
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "addLaps" {
                            AddLapView(
                                onAdd: { newLapDataArray in
                                let existingLaps = Array(race.laps ?? [])
                                for lap in existingLaps {
                                    modelContext.delete(lap)
                                }
                            for (index, lapData) in newLapDataArray.enumerated() {
                                let lap = Lap(
                                    lapNumber: index + 1,
                                    distance: lapData.distance,
                                    time: lapData.time
                                )
                                lap.raceRecord = race
                                modelContext.insert(lap)
                            }
                            race.totalTime = newLapDataArray.reduce(0) { $0 + $1.time }
                            do {
                                try modelContext.save()
                                navigationPath.removeLast()
                            } catch {
                                // エラーハンドリング
                            }
                        },
                        raceType: race.raceType,
                        totalDistance: race.totalDistance,
                        totalDistanceProvider: { race.totalDistance },
                        initialLaps: (race.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map {
                            LapData(distance: $0.distance, time: $0.time)
                        }
                    )
                } else if destination == "edit" {
                    AddRaceView(raceToEdit: race)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(destination: AddRaceView(raceToEdit: race)) {
                        Text("編集")
                    }
                }
            }
        }
    }

    private func distanceDisplayName() -> String {
        // matches\u30e1\u30bd\u30c3\u30c9\u3092\u4f7f\u7528\u3057\u3066\u7a2e\u76ee\u540d\u3092\u691c\u7d22
        if let match = distances.first(where: { 
            $0.matches(distance: race.totalDistance) && 
            $0.raceType == race.raceType 
        }) {
            return match.name
        }
        return String(format: "%.2f km", race.totalDistance)
    }

    private func recalcTotalTime() -> Double {
        (race.laps ?? []).reduce(0) { $0 + $1.time }
    }
}

#Preview {
    let container = try! ModelContainer(for: RaceRecord.self, Lap.self, RaceDistance.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
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

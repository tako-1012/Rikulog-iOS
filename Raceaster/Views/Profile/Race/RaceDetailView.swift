import SwiftUI
import SwiftData

/// レース記録の詳細ビュー
struct RaceDetailView: View {
    let race: RaceRecord
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceDistance.sortOrder) private var distances: [RaceDistance]
    @Query(sort: \RaceRecord.date, order: .reverse) private var allRaces: [RaceRecord]
    @Query private var userProfiles: [UserProfile]
    @State private var navigationPath: NavigationPath = NavigationPath()
    @State private var showingShareSheet = false
    
    private var userProfile: UserProfile { userProfiles.first ?? UserProfile() }
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            List {
                // 基本情報
                Section("race.detail.basic.section") {
                    LabeledContent("race.detail.competition.name", value: race.raceName)
                    LabeledContent("race.detail.date") {
                        Text(race.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP"))))
                    }
                    LabeledContent("race.detail.type", value: race.raceType.displayName)
                    LabeledContent("race.detail.event", value: distanceDisplayName())

                    if race.raceType == .field {
                        // フィールド種目：記録を表示
                        if let fh = race.fieldHeight {
                            LabeledContent("race.detail.record", value: formatFieldRecord(fh))
                        } else if let fd = race.fieldDistance {
                            LabeledContent("race.detail.record", value: formatFieldRecord(fd))
                        }
                        if let ws = race.windSpeed {
                            LabeledContent("race.detail.wind", value: String(format: "%.1f m/s", ws))
                        }
                        if race.isWindAided == true {
                            HStack {
                                Image(systemName: "wind").foregroundStyle(.orange)
                                Text("race.detail.wind.aided").foregroundStyle(.orange)
                            }
                        }
                    } else {
                        // 走種目：距離・タイム・ペースを表示
                        LabeledContent("race.detail.distance", value: String(format: "%.2f km", race.totalDistance))
                        LabeledContent("race.detail.time", value: TimeFormatter.formatTimeWithFraction(race.totalTime))
                        LabeledContent("race.detail.pace", value: "\(TimeFormatter.formatPace(race.averagePace)) /km")
                    }
                }

                // 競技情報（フィールド・トラック・ロード）
                if race.raceType == .track {
                    Section("race.detail.competition.section") {
                        if let meetType = race.trackMeetType {
                            LabeledContent("race.detail.competition.type", value: meetType.displayName)
                        }
                        if let ranking = race.ranking {
                            LabeledContent("race.detail.competition.rank", value: "\(ranking)")
                        }
                        if let group = race.group {
                            LabeledContent("race.detail.competition.group", value: "\(group)")
                        }
                    }
                } else if race.raceType == .field, let ranking = race.ranking {
                    Section("race.detail.competition.section") {
                        LabeledContent("race.detail.competition.rank", value: "\(ranking)")
                    }
                }

                // フィールド種目の試技記録
                if race.raceType == .field, let json = race.attemptResults {
                    fieldAttemptsSection(json: json)
                }

                // VDOT情報（走種目のみ）
                if race.raceType != .field {
                    Section("race.detail.performance.section") {
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
                }

                // ラップタイム（走種目のみ）
                if race.raceType != .field, !(race.laps ?? []).isEmpty {
                    Section("race.detail.laps.section") {
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
                                onAdd: { newLapInputArray in
                                    let existingLaps = Array(race.laps ?? [])
                                    for lap in existingLaps { modelContext.delete(lap) }
                                    for (index, lapData) in newLapInputArray.enumerated() {
                                        let lap = Lap(
                                            lapNumber: index + 1,
                                            distance: lapData.distance,
                                            time: lapData.time
                                        )
                                        lap.raceRecord = race
                                        modelContext.insert(lap)
                                    }
                                    race.totalTime = newLapInputArray.reduce(0) { $0 + $1.time }
                                    do { try modelContext.save() } catch { print("⚠️ Lap update save failed: \(error)") }
                                },
                                raceType: race.raceType,
                                totalDistance: race.totalDistance,
                                totalDistanceProvider: { race.totalDistance },
                                initialLaps: (race.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map {
                                    LapInput(distance: $0.distance, time: $0.time)
                                }
                            )
                        ) {
                            HStack {
                                Label("race.detail.lap.edit", systemImage: "pencil")
                                Spacer()
                            }
                        }
                        .disabled(race.totalDistance <= 0)
                    }
                }
                
                // メモ
                if !race.memo.isEmpty {
                    Section("race.detail.memo.section") {
                        Text(race.memo)
                    }
                }
                
                // 共有カード導線
                Section {
                    Button(action: { showingShareSheet = true }) {
                        HStack(spacing: 12) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title3)
                                .foregroundStyle(.orange)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("race.detail.share")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                Text("race.detail.share.sub")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
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
                            print("⚠️ Lap edit save failed: \(error)")
                        }
                    },
                    raceType: race.raceType
                )
            }
            .navigationDestination(for: String.self) { destination in
                if destination == "addLaps" {
                            AddLapView(
                                onAdd: { newLapInputArray in
                                let existingLaps = Array(race.laps ?? [])
                                for lap in existingLaps {
                                    modelContext.delete(lap)
                                }
                            for (index, lapData) in newLapInputArray.enumerated() {
                                let lap = Lap(
                                    lapNumber: index + 1,
                                    distance: lapData.distance,
                                    time: lapData.time
                                )
                                lap.raceRecord = race
                                modelContext.insert(lap)
                            }
                            race.totalTime = newLapInputArray.reduce(0) { $0 + $1.time }
                            do {
                                try modelContext.save()
                                navigationPath.removeLast()
                            } catch {
                                print("⚠️ Lap add save failed: \(error)")
                            }
                        },
                        raceType: race.raceType,
                        totalDistance: race.totalDistance,
                        totalDistanceProvider: { race.totalDistance },
                        initialLaps: (race.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map {
                            LapInput(distance: $0.distance, time: $0.time)
                        }
                    )
                } else if destination == "edit" {
                    AddRaceView(raceToEdit: race)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    HStack(spacing: 16) {
                        Button(action: { showingShareSheet = true }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        NavigationLink(destination: AddRaceView(raceToEdit: race)) {
                            Text("common.edit")
                        }
                    }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareRaceView(race: race, userProfile: userProfile)
            }
        }
    }
    


    // MARK: フィールド種目 試技記録セクション
    @ViewBuilder
    private func fieldAttemptsSection(json: String) -> some View {
        let heightAttempts = FieldAttemptJSON.decodeHeightAttempts(from: json)
        let flatAttempts = FieldAttemptJSON.decodeAttempts(from: json)

        if !heightAttempts.isEmpty {
            Section("race.detail.height.attempts") {
                ForEach(heightAttempts) { ha in
                    HStack {
                        Text(formatFieldRecord(ha.height))
                            .font(.headline)
                            .frame(width: 70, alignment: .leading)
                        HStack(spacing: 6) {
                            ForEach(ha.results, id: \.self) { r in
                                Text(r == "o" ? "○" : r == "-" ? "−" : "×")
                                    .font(.subheadline.bold())
                                    .foregroundStyle(r == "o" ? Color.green : r == "-" ? Color.gray : Color.red)
                            }
                        }
                    }
                }
            }
        } else if !flatAttempts.isEmpty {
            Section("race.detail.attempts") {
                ForEach(flatAttempts.indices, id: \.self) { i in
                    HStack {
                        Text(String(format: String(localized: "field.attempt.label"), i + 1)).foregroundStyle(.secondary).frame(width: 60)
                        if flatAttempts[i].isFoul {
                            Text("field.attempt.foul").foregroundStyle(.red)
                        } else {
                            Text(formatFieldRecord(flatAttempts[i].result))
                        }
                    }
                }
            }
        } else {
            // JSON が存在するが解析できなかった場合のフォールバック
            Section("race.detail.attempts") {
                Text("race.detail.attempts.empty")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
        }
    }

    private func distanceDisplayName() -> String {
        // matches\u30e1\u30bd\u30c3\u30c9\u3092\u4f7f\u7528\u3057\u3066\u7a2e\u76ee\u540d\u3092\u691c\u7d22
        if let match = distances.first(where: { 
            $0.matches(distance: race.totalDistance) && 
            $0.raceType == race.raceType 
        }) {
            return match.localizedName
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

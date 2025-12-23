import SwiftUI
import SwiftData

struct AddRaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 状態管理 (元のプロパティをすべて保持)
    @State private var raceName: String = ""
    @State private var date: Date = Date()
    @State private var raceType: RaceType = .track
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var secondsText: String = ""
    @State private var memo: String = ""
    @State private var officialTimeText: String = ""
    @State private var trackMeetType: TrackMeetType = .timeTrial
    @State private var rankingText: String = ""
    @State private var groupText: String = ""
    @State private var isRelay: Bool = false
    @State private var relayStageText: String = ""
    @State private var laps: [LapData] = []
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var selectedDistanceId: PersistentIdentifier? = nil
    @State private var isOtherSelected = false
    @State private var customDistanceText: String = ""
    @State private var useCustomDistance = false
    @State private var includeInVDOT: Bool = true
    
    @FocusState private var isEditingFields: Bool
    @FocusState private var focusedTimeField: TimeInputFields.FocusedField?

    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    var raceToEdit: RaceRecord? = nil

    // MARK: - 初期化 (既存データの復元ロジックを完全維持)
    init(raceToEdit: RaceRecord? = nil) {
        self.raceToEdit = raceToEdit
        if let r = raceToEdit {
            _raceName = State(initialValue: r.raceName)
            _date = State(initialValue: r.date)
            _raceType = State(initialValue: r.raceType)
            let comp = breakdownTimeStatic(r.totalTime)
            _hoursText = State(initialValue: String(comp.h))
            _minutesText = State(initialValue: String(comp.m))
            _secondsText = State(initialValue: String(format: "%.2f", comp.s))
            _memo = State(initialValue: r.memo)
            _trackMeetType = State(initialValue: r.trackMeetType ?? .timeTrial)
            _rankingText = State(initialValue: r.ranking.map { String($0) } ?? "")
            _officialTimeText = State(initialValue: r.officialTime.map { String($0) } ?? "")
            _groupText = State(initialValue: r.group.map { String($0) } ?? "")
            _relayStageText = State(initialValue: r.relayStage.map { String($0) } ?? "")
            _isRelay = State(initialValue: r.isRelay)
            _laps = State(initialValue: (r.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map { LapData(distance: $0.distance, time: $0.time) })
            _includeInVDOT = State(initialValue: r.includeInVDOT)
            _useCustomDistance = State(initialValue: true)
            _isOtherSelected = State(initialValue: true)
            _customDistanceText = State(initialValue: String(format: "%.3f", r.totalDistance))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                // コンパイラ負荷を分散するためSectionをグループ化して呼び出し
                Group {
                    typeSection
                    basicSection
                    distanceSection
                }
                Group {
                    timeSection
                    competitionSection
                    memoAndVDOTSection
                    lapSection
                }
            }
            .navigationTitle(raceToEdit == nil ? "レース記録を追加" : "レース記録を編集")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { saveRace() }.bold()
                }
            }
            .sheet(item: $activeSheet) { sheetDestination(for: $0) }
            .alert("エラー", isPresented: $showingError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            // ✅ これで浮いたボタンを消し、キーボードの上に完了を表示
            .keyboardDoneToolbar {
                isEditingFields = false
                focusedTimeField = nil
            }
        }
        .onAppear {
            // フォールバック: デフォルト種目が不足しているものだけを挿入する
            let defaults = RaceDistance.createDefaultDistances()
            var inserted = 0
            for distance in defaults {
                let exists = distances.contains { existing in
                    abs(existing.distanceKm - distance.distanceKm) < 0.0001 && existing.raceType == distance.raceType
                }
                if !exists { modelContext.insert(distance); inserted += 1 }
            }
            if inserted > 0 { try? modelContext.save() }
        }
    }
}

// MARK: - UI Sections (Viewを分割してコンパイルエラーを回避)
extension AddRaceView {
    private var typeSection: some View {
        Section("レース種類") {
            Picker("種類", selection: $raceType) {
                Text("トラック").tag(RaceType.track)
                Text("ロード").tag(RaceType.road)
                Text("その他").tag(RaceType.other)
            }
            .pickerStyle(.segmented)
            .onChange(of: raceType) { _, _ in resetDistanceSelection() }
        }
    }

    private var basicSection: some View {
        Section("基本情報") {
            TextField("大会名", text: $raceName).focused($isEditingFields)
            DatePicker("開催日", selection: $date, in: ...Date(), displayedComponents: .date)
                .environment(\.locale, Locale(identifier: "ja_JP"))
        }
    }

    private var distanceSection: some View {
        Section("種目（距離）") {
            Text("登録種目数: \(distances.filter { $0.raceType == raceType }.count)").font(.caption).foregroundStyle(.secondary)
            DistancePickerView(
                raceType: raceType, distances: distances,
                selectedDistanceId: $selectedDistanceId, isOtherSelected: $isOtherSelected,
                useCustomDistance: $useCustomDistance, customDistanceText: $customDistanceText,
                accessoryEnabled: false // 浮いたボタンを消す
            )
            if useCustomDistance && isOtherSelected {
                HStack {
                    TextField("距離 (km)", text: $customDistanceText).keyboardType(.decimalPad).focused($isEditingFields)
                    Text("km")
                }
            }
        }
    }

    private var timeSection: some View {
        Section("正式タイム") {
            TimeInputFields(hoursText: $hoursText, minutesText: $minutesText, secondsText: $secondsText, focusedField: _focusedTimeField, onNormalize: { normalizeTime() }, accessoryEnabled: true)
        }
    }

    @ViewBuilder
    private var competitionSection: some View {
        if raceType == .track {
            Section("競技情報") {
                Picker("種別", selection: $trackMeetType) {
                    Text("記録会").tag(TrackMeetType.timeTrial)
                    Text("予選").tag(TrackMeetType.preliminary)
                    Text("決勝").tag(TrackMeetType.final)
                }.pickerStyle(.segmented)
                HStack { Text("組"); TextField("組", text: $groupText).keyboardType(.numberPad).focused($isEditingFields); Text("組") }
                HStack { Text("順位"); TextField("順位", text: $rankingText).keyboardType(.numberPad).focused($isEditingFields); Text("位") }
            }
        } else if raceType == .road {
            Section("競技情報") {
                Toggle("駅伝", isOn: $isRelay)
                if isRelay {
                    HStack { Text("区間"); TextField("区間", text: $relayStageText).keyboardType(.numberPad).focused($isEditingFields); Text("区") }
                }
                HStack { Text("順位"); TextField("順位", text: $rankingText).keyboardType(.numberPad).focused($isEditingFields); Text("位") }
            }
        }
    }

    private var memoAndVDOTSection: some View {
        Group {
            Section("メモ") { TextEditor(text: $memo).frame(minHeight: 100).focused($isEditingFields) }
            Section {
                Toggle("VDOT計測に含める", isOn: $includeInVDOT)
            } footer: {
                Text("駆け引きのあるレースなど、実力を反映しない記録の場合はオフにしてください")
            }
        }
    }

    private var lapSection: some View {
        LapListSection(laps: $laps, raceType: raceType) { idx in
            activeSheet = (idx == -1) ? .addLap : .editLap(idx)
        }
    }
}

// MARK: - Logic (保存処理などを完全復元)
extension AddRaceView {
    func saveRace() {
        if raceName.isEmpty { errorMessage = "大会名を入力してください"; showingError = true; return }
        
        let dist = useCustomDistance ? (Double(customDistanceText) ?? 0) : (distances.first { $0.persistentModelID == selectedDistanceId }?.distanceKm ?? 0)
        let minAllowedDistanceKm: Double = (raceType == .track) ? 0.1 : 0.1
        if dist < minAllowedDistanceKm || dist > 500 { errorMessage = "有効な距離を入力してください"; showingError = true; return }

        let h = Double(hoursText) ?? 0; let m = Double(minutesText) ?? 0; let s = Double(secondsText) ?? 0
        let total = h * 3600 + m * 60 + s
        if total <= 0 || total >= 86400 { errorMessage = "有効なタイムを入力してください"; showingError = true; return }

        do {
                if let r = raceToEdit {
                // 既存レコード更新
                r.raceName = raceName; r.date = date; r.raceType = raceType
                r.totalDistance = dist; r.totalTime = total; r.memo = memo
                // 種目に応じて正規化して保存
                r.trackMeetType = (raceType == .track) ? trackMeetType : nil
                r.ranking = Int(rankingText); r.group = Int(groupText)
                r.setTotalTimeFromInput(total)
                r.setOfficialTimeFromInput(Double(officialTimeText) ?? total)
                r.includeInVDOT = includeInVDOT; r.isRelay = (raceType == .road) ? isRelay : false
                r.relayStage = (raceType == .road && isRelay) ? Int(relayStageText) : nil
                
                for lap in (r.laps ?? []) { modelContext.delete(lap) }
                r.laps = laps.enumerated().map { (i, d) in
                    let lap = Lap(lapNumber: i + 1, distance: d.distance, time: d.time)
                    lap.raceRecord = r; return lap
                }
            } else {
                // 新規作成
                let lapModels = laps.enumerated().map { (i, d) in Lap(lapNumber: i + 1, distance: d.distance, time: d.time) }
                let new = RaceRecord(raceName: raceName, date: date, raceType: raceType, totalDistance: dist, totalTime: total, memo: memo, trackMeetType: (raceType == .track ? trackMeetType : nil), ranking: Int(rankingText), laps: lapModels, officialTime: Double(officialTimeText) ?? total, includeInVDOT: includeInVDOT, group: Int(groupText), isRelay: (raceType == .road ? isRelay : false), relayStage: Int(relayStageText))
                lapModels.forEach { $0.raceRecord = new; modelContext.insert($0) }
                modelContext.insert(new)
            }
            try modelContext.save(); dismiss()
        } catch {
            errorMessage = "保存に失敗しました"; showingError = true
        }
    }

    private func normalizeTime() {
        let n = TimeInputNormalizer.normalize(hoursText: hoursText, minutesText: minutesText, secondsText: secondsText)
        hoursText = n.hours; minutesText = n.minutes; secondsText = n.seconds
    }

    private func resetDistanceSelection() {
        selectedDistanceId = nil; isOtherSelected = false; useCustomDistance = false; customDistanceText = ""
    }

    @ViewBuilder
    private func sheetDestination(for sheet: ActiveSheet) -> some View {
        switch sheet {
        case .addDistance: AddDistanceView { new in selectedDistanceId = new.persistentModelID }
        case .addLap:
            // 現在フォームで選択されている距離（km単位）を AddLapView に渡す
            let currentSelectedDistance: Double = useCustomDistance ? (Double(customDistanceText) ?? 0) : (distances.first { $0.persistentModelID == selectedDistanceId }?.distanceKm ?? 0)
            AddLapView(
                onAdd: { laps = $0 },
                raceType: raceType,
                totalDistance: currentSelectedDistance,
                totalDistanceProvider: { useCustomDistance ? (Double(customDistanceText) ?? 0) : (distances.first { $0.persistentModelID == selectedDistanceId }?.distanceKm ?? 0) },
                initialLaps: laps
            )
        case .editLap(let idx): if laps.indices.contains(idx) { EditLapTimeView(lapNumber: idx+1, distanceKm: laps[idx].distance, initialSeconds: Int(laps[idx].time), onSave: { laps[idx].time = Double($0) }, raceType: raceType) }
        }
    }
    
    private func breakdownTimeStatic(_ s: Double) -> (h: Int, m: Int, s: Double) {
        let h = Int(s) / 3600; let m = (Int(s) % 3600) / 60; let sec = s.truncatingRemainder(dividingBy: 60)
        return (h, m, sec)
    }
}
import SwiftUI
import SwiftData
import UIKit

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
    @State private var laps: [LapInput] = []
    @State private var activeSheet: ActiveSheet? = nil
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showRankAlert = false
    @State private var rankAlertTitle = ""
    @State private var rankAlertMessage = ""
    @State private var selectedDistanceId: PersistentIdentifier? = nil
    @State private var isOtherSelected = false
    @State private var customDistanceText: String = ""
    @State private var useCustomDistance = false
    @State private var includeInVDOT: Bool = true

    // MARK: - フィールド種目専用状態
    @State private var fieldMetersText: String = ""
    @State private var fieldCmText: String = ""
    @State private var windSpeedText: String = ""
    @State private var fieldAttempts: [FieldAttempt] = []
    @State private var fieldHeightAttempts: [FieldHeightAttempt] = []

    @FocusState private var isEditingFields: Bool
    @FocusState private var focusedTimeField: TimeInputFields.FocusedField?

    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    var raceToEdit: RaceRecord? = nil

    /// 現在選択中のフィールド種目
    private var selectedFieldDistance: RaceDistance? {
        distances.first { $0.persistentModelID == selectedDistanceId }
    }

    // MARK: - 初期化 (既存データの復元ロジックを完全維持)
    init(raceToEdit: RaceRecord? = nil) {
        self.raceToEdit = raceToEdit
        if let r = raceToEdit {
            _raceName = State(initialValue: r.raceName)
            _date = State(initialValue: r.date)
            _raceType = State(initialValue: r.raceType)
            _memo = State(initialValue: r.memo)
            _rankingText = State(initialValue: r.ranking.map { String($0) } ?? "")
            _includeInVDOT = State(initialValue: r.includeInVDOT)

            if r.raceType == .field {
                // フィールド種目の復元
                let fieldVal = r.fieldHeight ?? r.fieldDistance ?? 0
                let m = Int(fieldVal)
                let cm = Int(((fieldVal - Double(m)) * 100).rounded())
                _fieldMetersText = State(initialValue: m > 0 ? String(m) : "")
                _fieldCmText = State(initialValue: cm > 0 ? String(format: "%02d", cm) : "")
                _windSpeedText = State(initialValue: r.windSpeed.map { String(format: "%.1f", $0) } ?? "")
                if let json = r.attemptResults {
                    // JSON から試技を復元（高さ種目か否かで分岐）
                    let heightAttempts = FieldAttemptJSON.decodeHeightAttempts(from: json)
                    let flatAttempts = FieldAttemptJSON.decodeAttempts(from: json)
                    _fieldHeightAttempts = State(initialValue: heightAttempts)
                    _fieldAttempts = State(initialValue: flatAttempts)
                }
                // 種目選択を復元（distanceKm で照合）
                _useCustomDistance = State(initialValue: false)
                _isOtherSelected = State(initialValue: false)
            } else {
                // 既存の走種目の復元
                let comp = breakdownTimeStatic(r.totalTime)
                _hoursText = State(initialValue: String(comp.h))
                _minutesText = State(initialValue: String(comp.m))
                _secondsText = State(initialValue: String(format: "%.2f", comp.s))
                _trackMeetType = State(initialValue: r.trackMeetType ?? .timeTrial)
                _officialTimeText = State(initialValue: r.officialTime.map { String($0) } ?? "")
                _groupText = State(initialValue: r.group.map { String($0) } ?? "")
                _relayStageText = State(initialValue: r.relayStage.map { String($0) } ?? "")
                _isRelay = State(initialValue: r.isRelay)
                _laps = State(initialValue: (r.laps ?? []).sorted(by: { $0.lapNumber < $1.lapNumber }).map { LapInput(distance: $0.distance, time: $0.time) })
                _useCustomDistance = State(initialValue: true)
                _isOtherSelected = State(initialValue: true)
                _customDistanceText = State(initialValue: String(format: "%.3f", r.totalDistance))
            }
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
                if raceType == .field {
                    Group {
                        fieldRecordSection
                        fieldCompetitionSection
                        memoSection
                    }
                } else {
                    Group {
                        timeSection
                        competitionSection
                        memoAndVDOTSection
                        lapSection
                    }
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("keyboard.done") {
                        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    }
                }
            }
            .navigationTitle(raceToEdit == nil ? LocalizedStringKey("race.add.title") : LocalizedStringKey("race.edit.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { saveRace() }.bold()
                }
            }
            .onAppear {
                // フィールド種目の編集時：init では @Query にアクセスできないため
                // onAppear で selectedDistanceId を復元する
                if let r = raceToEdit, r.raceType == .field, selectedDistanceId == nil {
                    selectedDistanceId = distances.first {
                        abs($0.distanceKm - r.totalDistance) < 0.001 && $0.raceType == .field
                    }?.persistentModelID
                }
            }
            .sheet(item: $activeSheet) { sheetDestination(for: $0) }
            .alert("common.error", isPresented: $showingError) {
                Button("common.ok") { }
            } message: {
                Text(errorMessage)
            }
            .alert(rankAlertTitle, isPresented: $showRankAlert) {
                Button("💪") { dismiss() }
            } message: {
                Text(rankAlertMessage)
            }
        }
    }
}

// MARK: - UI Sections (Viewを分割してコンパイルエラーを回避)
extension AddRaceView {
    private var typeSection: some View {
        Section("race.type.section") {
            Picker("race.type.picker.label", selection: $raceType) {
                Text("race.type.track").tag(RaceType.track)
                Text("race.type.road").tag(RaceType.road)
                Text("race.type.field").tag(RaceType.field)
                Text("race.type.other").tag(RaceType.other)
            }
            .pickerStyle(.segmented)
            .onChange(of: raceType) { _, _ in resetDistanceSelection() }
        }
    }

    // MARK: フィールド種目 最高記録・試技入力セクション
    @ViewBuilder
    private var fieldRecordSection: some View {
        if let fd = selectedFieldDistance {
            if fd.isHeightEvent {
                VerticalFieldSection(
                    eventName: fd.localizedName,
                    metersText: $fieldMetersText,
                    cmText: $fieldCmText,
                    heightAttempts: $fieldHeightAttempts
                )
            } else {
                HorizontalFieldSection(
                    eventName: fd.localizedName,
                    isJumpEvent: fd.subcategoryRaw == "jump",
                    metersText: $fieldMetersText,
                    cmText: $fieldCmText,
                    windSpeedText: $windSpeedText,
                    attempts: $fieldAttempts
                )
            }
        } else {
            Section("race.record.section") {
                Text("race.event.placeholder")
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: フィールド種目 競技情報（順位のみ）
    private var fieldCompetitionSection: some View {
        Section("race.competition.section") {
            HStack {
                Text("race.competition.rank")
                TextField("race.competition.rank", text: $rankingText)
                    .keyboardType(.numberPad)
                    .focused($isEditingFields)
            }
        }
    }

    // MARK: メモのみ（フィールド種目用）
    private var memoSection: some View {
        Section("race.memo.section") {
            TextEditor(text: $memo)
                .frame(minHeight: 80)
                .focused($isEditingFields)
        }
    }

    private var basicSection: some View {
        Section("race.basic.section") {
            TextField("race.basic.name", text: $raceName)
                .focused($isEditingFields)
            DatePicker("race.basic.date", selection: $date, in: ...Date(), displayedComponents: .date)
        }
    }

    private var distanceSection: some View {
        Section(raceType == .field ? LocalizedStringKey("race.event.section") : LocalizedStringKey("race.event.section.distance")) {
            Text("race.event.count \(distances.filter { $0.raceType == raceType }.count)").font(.caption).foregroundStyle(.secondary)
            DistancePickerView(
                raceType: raceType, distances: distances,
                selectedDistanceId: $selectedDistanceId, isOtherSelected: $isOtherSelected,
                useCustomDistance: $useCustomDistance, customDistanceText: $customDistanceText,
                accessoryEnabled: false // 浮いたボタンを消す
            )
            if useCustomDistance && isOtherSelected {
                HStack {
                    TextField("race.distance.km", text: $customDistanceText).keyboardType(.decimalPad).focused($isEditingFields)
                    Text("km")
                }
            }
        }
    }

    private var timeSection: some View {
        Section("race.time.section") {
            TimeInputFields(hoursText: $hoursText, minutesText: $minutesText, secondsText: $secondsText, focusedField: _focusedTimeField, onNormalize: {
                let n = TimeInputNormalizer.normalize(hoursText: hoursText, minutesText: minutesText, secondsText: secondsText)
                hoursText = n.hours; minutesText = n.minutes; secondsText = n.seconds
            }, accessoryEnabled: true)
        }
    }

    @ViewBuilder
    private var competitionSection: some View {
        if raceType == .track {
            Section("race.competition.section") {
                Picker("race.competition.type.picker", selection: $trackMeetType) {
                    Text("race.competition.time.trial").tag(TrackMeetType.timeTrial)
                    Text("race.competition.preliminary").tag(TrackMeetType.preliminary)
                    Text("race.competition.final").tag(TrackMeetType.final)
                }.pickerStyle(.segmented)
                HStack { 
                    Text("race.competition.group")
                    TextField("race.competition.group", text: $groupText).keyboardType(.numberPad).focused($isEditingFields)
                    Text("race.competition.group") 
                }
                HStack {
                    Text("race.competition.rank")
                    TextField("race.competition.rank", text: $rankingText).keyboardType(.numberPad).focused($isEditingFields)
                }
            }
        } else if raceType == .road {
            Section("race.competition.section") {
                Toggle("race.competition.relay", isOn: $isRelay)
                if isRelay {
                    HStack {
                        Text("race.competition.relay.stage")
                        TextField("race.competition.relay.stage", text: $relayStageText).keyboardType(.numberPad).focused($isEditingFields)
                        Text("race.relay.stage.suffix")
                    }
                }
                HStack {
                    Text("race.competition.rank")
                    TextField("race.competition.rank", text: $rankingText).keyboardType(.numberPad).focused($isEditingFields)
                }
            }
        }
    }

    private var memoAndVDOTSection: some View {
        Group {
            Section("race.memo.section") {
                TextEditor(text: $memo)
                    .frame(minHeight: 100)
                    .focused($isEditingFields)
            }
            Section {
                Toggle("race.vdot.toggle", isOn: $includeInVDOT)
            } footer: {
                Text("race.vdot.footer")
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
        if raceName.isEmpty { errorMessage = String(localized: "race.basic.name") + String(localized: "common.error"); showingError = true; return }

        // フィールド種目は専用の保存ロジックへ
        if raceType == .field {
            saveFieldRace()
            return
        }

        let dist = useCustomDistance ? (Double(customDistanceText) ?? 0) : (distances.first { $0.persistentModelID == selectedDistanceId }?.distanceKm ?? 0)
        let minAllowedDistanceKm: Double = (raceType == .track) ? 0.1 : 0.1
        if dist < minAllowedDistanceKm || dist > 500 { errorMessage = String(localized: "race.distance.km"); showingError = true; return }

        let h = Double(hoursText) ?? 0; let m = Double(minutesText) ?? 0; let s = Double(secondsText) ?? 0
        let total = h * 3600 + m * 60 + s
        if total <= 0 || total >= 86400 { errorMessage = String(localized: "race.time.section"); showingError = true; return }

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
                let lapModels = laps.enumerated().map { (i, d) in Lap.from(d, lapNumber: i + 1) }
                let new = RaceRecord(raceName: raceName, date: date, raceType: raceType, totalDistance: dist, totalTime: total, memo: memo, trackMeetType: (raceType == .track ? trackMeetType : nil), ranking: Int(rankingText), laps: lapModels, officialTime: Double(officialTimeText) ?? total, includeInVDOT: includeInVDOT, group: Int(groupText), isRelay: (raceType == .road ? isRelay : false), relayStage: Int(relayStageText))
                lapModels.forEach { $0.raceRecord = new; modelContext.insert($0) }
                modelContext.insert(new)
            }
            try modelContext.save()
            
            // Haptic フィードバック
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            
            // ランキング判定（新規作成時のみ）
            if raceToEdit == nil {
                checkRanking(distance: dist, time: total, raceType: raceType)
            }
            
            // ランキングアラート表示中はdismissしない（アラートのボタンでdismiss）
            if !showRankAlert {
                dismiss()
            }
        } catch {
            errorMessage = String(localized: "common.error"); showingError = true
        }
    }
    
    // MARK: - フィールド種目 保存処理
    private func saveFieldRace() {
        guard let fd = selectedFieldDistance else {
            errorMessage = String(localized: "race.event.section"); showingError = true; return
        }

        let meters = Double(fieldMetersText) ?? 0
        let cm = Double(fieldCmText) ?? 0
        let fieldValue = meters + cm / 100
        if fieldValue <= 0 { errorMessage = String(localized: "race.detail.record"); showingError = true; return }

        let isHeight = fd.isHeightEvent
        let ws = Double(windSpeedText)
        let windAided = ws.map { $0 > 2.0 } ?? false

        // 試技結果のJSON化
        let attemptsJSON: String?
        if isHeight {
            attemptsJSON = fieldHeightAttempts.isEmpty ? nil : FieldAttemptJSON.encode(heightAttempts: fieldHeightAttempts)
        } else {
            attemptsJSON = fieldAttempts.isEmpty ? nil : FieldAttemptJSON.encode(attempts: fieldAttempts)
        }

        // distanceKm を totalDistance として使用（種目識別子として機能）
        let identifierKm = fd.distanceKm

        do {
            if let r = raceToEdit {
                r.raceName = raceName; r.date = date; r.raceType = .field
                r.totalDistance = identifierKm; r.totalTime = 1.0  // 走タイムは不使用
                r.memo = memo; r.ranking = Int(rankingText)
                r.fieldDistance = isHeight ? nil : fieldValue
                r.fieldHeight = isHeight ? fieldValue : nil
                r.attemptResults = attemptsJSON
                r.windSpeed = ws; r.isWindAided = windAided
                r.includeInVDOT = false  // フィールド種目はVDOT対象外
            } else {
                let new = RaceRecord(
                    raceName: raceName, date: date, raceType: .field,
                    totalDistance: identifierKm, totalTime: 1.0,
                    memo: memo, ranking: Int(rankingText), includeInVDOT: false
                )
                new.fieldDistance = isHeight ? nil : fieldValue
                new.fieldHeight = isHeight ? fieldValue : nil
                new.attemptResults = attemptsJSON
                new.windSpeed = ws; new.isWindAided = windAided
                modelContext.insert(new)
            }
            try modelContext.save()
            let generator = UINotificationFeedbackGenerator()
            generator.notificationOccurred(.success)
            dismiss()
        } catch {
            errorMessage = String(localized: "common.error"); showingError = true
        }
    }

    private func checkRanking(distance: Double, time: Double, raceType: RaceType) {
        let matchingDistance = distances.first { d in
            d.matches(distance: distance) && d.raceType == raceType
        }
        guard let distModel = matchingDistance else { return }
        
        let descriptor = FetchDescriptor<RaceRecord>()
        guard let allRaces = try? modelContext.fetch(descriptor) else { return }
        let matchingRaces = allRaces.filter { r in
            distModel.matches(distance: r.totalDistance) && r.raceType == distModel.raceType
        }
        
        // 2件以上ないとランキングの意味がない
        guard matchingRaces.count > 1 else { return }
        
        // タイム順にソートしてランキングを判定
        let sorted = matchingRaces.sorted { $0.totalTime < $1.totalTime }
        guard let rank = sorted.firstIndex(where: { abs($0.totalTime - time) < 0.01 }) else { return }
        let position = rank + 1 // 1-indexed
        
        let name = distModel.localizedName
        let totalCount = matchingRaces.count
        
        switch position {
        case 1:
            rankAlertTitle = String(localized: "rank.alert.pb.title")
            rankAlertMessage = String(format: String(localized: "rank.alert.pb.message %@"), name)
        case 2:
            rankAlertTitle = String(localized: "rank.alert.2nd.title")
            rankAlertMessage = String(format: String(localized: "rank.alert.2nd.message %@ %lld"), name, totalCount)
        case 3:
            rankAlertTitle = String(localized: "rank.alert.3rd.title")
            rankAlertMessage = String(format: String(localized: "rank.alert.3rd.message %@ %lld"), name, totalCount)
        case 4, 5:
            rankAlertTitle = String(localized: "rank.alert.top5.title")
            rankAlertMessage = String(format: String(localized: "rank.alert.top5.message %@ %lld %lld"), name, totalCount, position)
        default:
            return // 6位以下はアラートなし
        }
        
        showRankAlert = true
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
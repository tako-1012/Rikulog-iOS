import SwiftUI
import SwiftData

/// ペース計算ビュー
struct PaceCalculatorView: View {
    @Query(sort: \RaceDistance.sortOrder) private var distances: [RaceDistance]
    @StateObject private var viewModel = PaceCalculatorViewModel()
    
    // TimeInputFields用のFocusStateは定義だけ残しておきますが、干渉させません
    @FocusState private var focusedTimeField: TimeInputFields.FocusedField?
    @FocusState private var focusedPaceField: TimeInputFields.FocusedField?

    public init() {}

    var body: some View {
        NavigationStack {
            Form {
                modeSection
                distanceSection
                timeSection
                paceSection
                calculateButtonSection
                resultSection
                lapPresetSection
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("ペース計算")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: distances) { _, newDistances in
                viewModel.distances = newDistances
                if let selectedId = viewModel.selectedDistanceId {
                    if !newDistances.contains(where: { $0.persistentModelID == selectedId }) {
                        viewModel.selectedDistanceId = nil
                        viewModel.clearSelectedDistance()
                    }
                }
            }
            .onAppear {
                viewModel.distances = distances
            }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    EmptyView()
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var modeSection: some View {
        Section("計算モード") {
            Picker("計算する値", selection: $viewModel.mode) {
                Text("ペース").tag(PaceCalculatorViewModel.CalculationMode.calculatePace)
                Text("時間").tag(PaceCalculatorViewModel.CalculationMode.calculateTime)
                Text("距離").tag(PaceCalculatorViewModel.CalculationMode.calculateDistance)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var distanceSection: some View {
        Group {
            if viewModel.mode != .calculateDistance {
                Section("距離") {
                    VStack(alignment: .leading, spacing: 12) {
                        if !distances.isEmpty {
                            distanceSelectorPart
                            Divider()
                        }
                        distanceInputPart
                    }
                    .onChange(of: viewModel.distance) { _, new in
                        viewModel.handleDistanceInputChange()
                    }
                }
            }
        }
    }
    
    private var distanceSelectorPart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("登録種目から選択")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("種目", selection: $viewModel.selectedDistanceId) {
                Text("選択しない").tag(nil as PersistentIdentifier?)
                Divider()
                
                let trackDistances = distances.filter { $0.raceType == .track }.sorted { $0.distanceKm < $1.distanceKm }
                if !trackDistances.isEmpty {
                    Section("トラック") {
                        ForEach(trackDistances, id: \.persistentModelID) { d in
                            Text(d.name).tag(d.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }
                
                let roadDistances = distances.filter { $0.raceType == .road }.sorted { $0.distanceKm < $1.distanceKm }
                if !roadDistances.isEmpty {
                    Section("ロード") {
                        ForEach(roadDistances, id: \.persistentModelID) { d in
                            Text(d.name).tag(d.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }
                
                let otherDistances = distances.filter { $0.raceType == .other }.sorted { $0.distanceKm < $1.distanceKm }
                if !otherDistances.isEmpty {
                    Section("その他") {
                        ForEach(otherDistances, id: \.persistentModelID) { d in
                            Text(d.name).tag(d.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }
            }
            .pickerStyle(.menu)
            .onChange(of: viewModel.selectedDistanceId) { _, newValue in
                if let id = newValue, let d = distances.first(where: { $0.persistentModelID == id }) {
                    viewModel.applyDistanceSelection(d)
                } else {
                    viewModel.clearSelectedDistance()
                }
            }
        }
    }
    
    private var distanceInputPart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("距離を入力")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                // ここは正常に動作しているはず
                AccessoryTextField(text: $viewModel.distance, placeholder: "0.0", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: true)
                    .submitLabel(.done)
                Text("km")
                    .foregroundStyle(.secondary)
            }
        }
    }
    
    private var timeSection: some View {
        Group {
            if viewModel.mode != .calculateTime {
                Section("時間") {
                    // 修正: simpleFocusBinding を .constant(false) にして監視を無効化
                    TimeInputFields(
                        hoursText: $viewModel.hoursText,
                        minutesText: $viewModel.minutesText,
                        secondsText: $viewModel.secondsText,
                        focusedField: _focusedTimeField,
                        simpleFocusBinding: .constant(false), // ← ここを修正！これで勝手に閉じなくなります
                        onNormalize: { viewModel.normalizeTimeFields() },
                        accessoryEnabled: true
                    )
                }
            }
        }
    }
    
    private var paceSection: some View {
        Group {
            if viewModel.mode != .calculatePace {
                Section("ペース (/km)") {
                    // 修正: simpleFocusBinding を .constant(false) にして監視を無効化
                    TimeInputFields(
                        hoursText: .constant(""),
                        minutesText: $viewModel.paceMinutesText,
                        secondsText: $viewModel.paceSecondsText,
                        focusedField: _focusedPaceField,
                        simpleFocusBinding: .constant(false), // ← ここを修正！
                        onNormalize: { viewModel.normalizePaceFields() },
                        accessoryEnabled: true
                    )
                }
            }
        }
    }
    
    private var calculateButtonSection: some View {
        Section {
            Button(action: {
                // 計算ボタンを押した時だけ確実に閉じる
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                
                viewModel.normalizeTimeFields()
                viewModel.normalizePaceFields()
                viewModel.calculate()
            }) {
                HStack {
                    Spacer()
                    Text("計算")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Spacer()
                }
                .padding()
                .background(Color.blue)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
    }
    
    private var resultSection: some View {
        Group {
            if !viewModel.resultText.isEmpty {
                Section("結果") {
                    Text(viewModel.resultText)
                        .font(.title2)
                        .foregroundStyle(.primary)
                }
            }
        }
    }
    
    private var lapPresetSection: some View {
        Group {
            if !viewModel.autoLaps.isEmpty || !viewModel.lapPreset.isEmpty {
                Section("ラップ距離プリセット") {
                    presetPickerPart
                    if viewModel.lapPreset == "custom" {
                        customLapInputPart
                    }
                    if !viewModel.autoLaps.isEmpty {
                        lapListPart
                    }
                }
            }
        }
    }
    
    private var presetPickerPart: some View {
        let availablePresets = viewModel.availableLapPresets()
        return Picker("ラップ距離", selection: $viewModel.lapPreset) {
            ForEach(availablePresets, id: \.self) { preset in
                Text(preset).tag(preset)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: viewModel.lapPreset) { _, new in
            viewModel.updateAutoLapsIfNeeded()
        }
    }
    
    private var customLapInputPart: some View {
        HStack {
            AccessoryTextField(text: $viewModel.customLapText, placeholder: "例: 400", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: true)
                .submitLabel(.done)
            Picker("単位", selection: $viewModel.customLapUnit) {
                Text("m").tag("m")
                Text("km").tag("km")
            }
            .pickerStyle(.segmented)
            .frame(width: 100)
        }
        .onChange(of: viewModel.customLapText) { _, new in
            viewModel.updateAutoLapsIfNeeded()
        }
        .onChange(of: viewModel.customLapUnit) { _, new in
            viewModel.updateAutoLapsIfNeeded()
        }
    }
    
    private var lapListPart: some View {
        Group {
            HStack {
                Text("自動生成ラップ一覧")
                    .font(.headline)
                Spacer()
                Text("\(viewModel.autoLaps.count)区間")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            .padding(.vertical, 4)
            
            let lapsSnapshot = viewModel.autoLaps
            let cumulativeTimes = buildCumulativeTimes(lapsSnapshot)
            
            ForEach(Array(lapsSnapshot.enumerated()), id: \.offset) { i, distKm in
                lapRowView(index: i, distKm: distKm, cumulative: cumulativeTimes[i])
            }
        }
    }
    
    private func buildCumulativeTimes(_ laps: [Double]) -> [Double] {
        guard let paceSecPerKm = viewModel.computedPaceSecondsPerKm, !laps.isEmpty else { return [] }
        var result: [Double] = []
        var sum: Double = 0.0
        for distKm in laps {
            let lapSeconds = paceSecPerKm * distKm
            sum += lapSeconds
            result.append(sum)
        }
        return result
    }
    
    @ViewBuilder
    private func lapRowView(index: Int, distKm: Double, cumulative: Double) -> some View {
        let useMeters = viewModel.lapPreset.contains("m") || viewModel.customLapUnit == "m"
        let distanceText: String = {
            if useMeters {
                return String(format: "%.0f m", distKm * 1000)
            } else {
                return String(format: "%.3f km", distKm)
            }
        }()

        if let paceSecPerKm = viewModel.computedPaceSecondsPerKm {
            let lapSecondsDouble = paceSecPerKm * distKm
            HStack {
                VStack(alignment: .leading) {
                    Text("Lap \(index+1): \(distanceText)")
                    Text("累積: \(TimeFormatter.formatTimeWithFraction(cumulative))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(TimeFormatter.formatTimeWithFraction(lapSecondsDouble))
                    .foregroundStyle(.blue)
            }
        } else {
            Text("Lap \(index+1): \(distanceText)")
        }
    }
}

#Preview {
    PaceCalculatorView()
        .modelContainer(for: [RaceDistance.self], inMemory: true)
}
import SwiftUI
import SwiftData

/// ペース計算ビュー
struct PaceCalculatorView: View {
    @Query(sort: \RaceDistance.sortOrder) private var distances: [RaceDistance]
    @StateObject private var viewModel = PaceCalculatorViewModel()
    
    // TimeInputFields用のFocusStateは定義だけ残しておきますが、干渉させません
    @FocusState private var focusedTimeField: TimeInputFields.FocusedField?
    @FocusState private var focusedPaceField: TimeInputFields.FocusedField?

    /// 画面上部で切り替えるツール
    private enum CalculatorTool: Hashable {
        case pace
        case treadmill
    }
    @State private var tool: CalculatorTool = .pace

    public init() {}

    var body: some View {
        NavigationStack {
            Form {
                toolPickerSection

                switch tool {
                case .pace:
                    // 結果を上部に表示（カード形式）
                    resultSection

                    modeSection

                    // 入力モードに応じたセクション表示
                    Group {
                        switch viewModel.mode {
                        case .calculatePace:
                            distanceSection
                            timeSection
                        case .calculateTime:
                            distanceSection
                            paceSection
                        case .calculateDistance:
                            timeSection
                            paceSection
                        }
                    }

                    calculateButtonSection
                    lapPresetSection
                case .treadmill:
                    treadmillSpeedToPaceSection
                    treadmillPaceToSpeedSection
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("calculator.title")
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
        Section("calculator.mode.section") {
            Picker("calculator.mode.picker.label", selection: $viewModel.mode) {
                Text("calculator.mode.pace").tag(PaceCalculatorViewModel.CalculationMode.calculatePace)
                Text("calculator.mode.time").tag(PaceCalculatorViewModel.CalculationMode.calculateTime)
                Text("calculator.mode.distance").tag(PaceCalculatorViewModel.CalculationMode.calculateDistance)
            }
            .pickerStyle(.segmented)
        }
    }
    
    private var distanceSection: some View {
        Section("calculator.distance.section") {
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
    
    private var distanceSelectorPart: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("calculator.distance.from.events")
                .font(.caption)
                .foregroundStyle(.secondary)
            Picker("calculator.distance.picker.label", selection: $viewModel.selectedDistanceId) {
                Text("calculator.distance.no.selection").tag(nil as PersistentIdentifier?)
                Divider()
                
                let trackDistances = distances.filter { $0.raceType == .track }.sorted { $0.distanceKm < $1.distanceKm }
                if !trackDistances.isEmpty {
                    Section("calculator.track.section") {
                        ForEach(trackDistances, id: \.persistentModelID) { d in
                            Text(d.localizedName).tag(d.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }

                let roadDistances = distances.filter { $0.raceType == .road }.sorted { $0.distanceKm < $1.distanceKm }
                if !roadDistances.isEmpty {
                    Section("calculator.road.section") {
                        ForEach(roadDistances, id: \.persistentModelID) { d in
                            Text(d.localizedName).tag(d.persistentModelID as PersistentIdentifier?)
                        }
                    }
                }

                let otherDistances = distances.filter { $0.raceType == .other }.sorted { $0.distanceKm < $1.distanceKm }
                if !otherDistances.isEmpty {
                    Section("calculator.other.section") {
                        ForEach(otherDistances, id: \.persistentModelID) { d in
                            Text(d.localizedName).tag(d.persistentModelID as PersistentIdentifier?)
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
            Text("calculator.distance.input")
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
        Section("calculator.time.section") {
            TimeInputFields(
                hoursText: $viewModel.hoursText,
                minutesText: $viewModel.minutesText,
                secondsText: $viewModel.secondsText,
                focusedField: _focusedTimeField,
                simpleFocusBinding: .constant(false),
                onNormalize: { viewModel.normalizeTimeFields() },
                accessoryEnabled: true
            )
        }
    }
    
    private var paceSection: some View {
        Section("calculator.pace.section") {
            TimeInputFields(
                hoursText: .constant(""),
                minutesText: $viewModel.paceMinutesText,
                secondsText: $viewModel.paceSecondsText,
                focusedField: _focusedPaceField,
                simpleFocusBinding: .constant(false),
                onNormalize: { viewModel.normalizePaceFields() },
                accessoryEnabled: true,
                showHours: false // ペース入力では時間を非表示
            )
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
                    Text("calculator.calculate")
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
                VStack(spacing: 12) {
                    Text("calculator.result.section")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    HStack(alignment: .center) {
                        Text(viewModel.resultMainValue) // ViewModelにcomputed propertyを追加する必要があります
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.leading)
                        
                        Spacer()
                        
                        Button(action: {
                            UIPasteboard.general.string = viewModel.resultText
                            let generator = UINotificationFeedbackGenerator()
                            generator.notificationOccurred(.success)
                        }) {
                            Image(systemName: "doc.on.doc")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
                .padding(.top, 8)
            }
        }
    }
    
    // MARK: - ツール切り替え

    private var toolPickerSection: some View {
        Section {
            Picker("", selection: $tool) {
                Text("calculator.title").tag(CalculatorTool.pace)
                Text("treadmill.section.title").tag(CalculatorTool.treadmill)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    // MARK: - トレッドミル換算

    private var treadmillSpeedToPaceSection: some View {
        Section("treadmill.speed.label") {
            HStack(spacing: 8) {
                AccessoryTextField(text: $viewModel.treadmillSpeedText, placeholder: "10.0", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: true)
                    .frame(width: 88)
                Text("km/h")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Spacer(minLength: 8)
                treadmillResult(value: viewModel.treadmillPaceResult, unit: "/km")
            }
        }
    }

    private var treadmillPaceToSpeedSection: some View {
        Section("treadmill.pace.label") {
            HStack(spacing: 6) {
                AccessoryTextField(text: $viewModel.treadmillPaceMinutesText, placeholder: "5", keyboardType: .numberPad, isFirstResponder: nil, showAccessory: true)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                Text(":")
                    .foregroundStyle(.secondary)
                AccessoryTextField(text: $viewModel.treadmillPaceSecondsText, placeholder: "30", keyboardType: .numberPad, isFirstResponder: nil, showAccessory: true)
                    .multilineTextAlignment(.center)
                    .frame(width: 52)
                Text("/km")
                    .foregroundStyle(.secondary)
                    .fixedSize()
                Spacer(minLength: 8)
                treadmillResult(value: viewModel.treadmillSpeedResult, unit: "km/h")
            }
        }
    }

    /// 換算結果（"→ 17.1 km/h" など）を1行で表示する
    @ViewBuilder
    private func treadmillResult(value: String?, unit: String) -> some View {
        if let value {
            HStack(spacing: 4) {
                Image(systemName: "arrow.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.title3.bold())
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                Text(unit)
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
            .fixedSize()
        }
    }

    private var lapPresetSection: some View {
        Group {
            if !viewModel.autoLaps.isEmpty || !viewModel.lapPreset.isEmpty {
                Section("calculator.laps.section") {
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
        return Picker("calculator.laps.distance.picker", selection: $viewModel.lapPreset) {
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
            Picker("calculator.unit.picker", selection: $viewModel.customLapUnit) {
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
                Text("calculator.laps.auto.label")
                    .font(.headline)
                Spacer()
                Text("lap.count \(viewModel.autoLaps.count)")
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
                    Text(String(localized: "calculator.mode.time") + ": \(TimeFormatter.formatTimeWithFraction(cumulative))")
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
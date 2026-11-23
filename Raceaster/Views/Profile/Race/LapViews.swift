import SwiftUI
import SwiftData

/// ラップタイム編集ビュー
struct EditLapTimeView: View {
    @Environment(\.dismiss) private var dismiss
    let lapNumber: Int
    let distanceKm: Double
    let initialSeconds: Int
    let onSave: (Int) -> Void
    let raceType: RaceType
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var secondsText: String = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    // Avoid binding a shared FocusState to UIKit-backed fields here.
    // We'll explicitly dismiss the keyboard when needed.

    var body: some View {
        NavigationStack {
            Form {
                Section("lap.info.section") {
                    HStack {
                        Text("Lap \(lapNumber)")
                        Spacer()
                        let distanceDisplay = raceType == .track
                            ? String(format: "%.0f", distanceKm * 1000) + "m"
                            : String(format: "%.1f", distanceKm) + "km"
                        Text(distanceDisplay)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("lap.time.section") {
                    HStack(spacing: 12) {
                        VStack {
                            TextField("0", text: $hoursText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .submitLabel(.done)
                                .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                                .clearZeroOnFocus($hoursText)
                            Text("common.hour").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(":").font(.title2)
                        VStack {
                            TextField("0", text: $minutesText)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .submitLabel(.done)
                                .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                                .clearZeroOnFocus($minutesText)
                            Text("common.minute").font(.caption).foregroundStyle(.secondary)
                        }
                        Text(":").font(.title2)
                        VStack {
                            TextField("0.0", text: $secondsText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.center)
                                .frame(width: 60)
                                .submitLabel(.done)
                                .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                                .clearZeroOnFocus($secondsText)
                            Text("common.second").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        normalizeEditFields()
                        let h = Int(hoursText) ?? 0
                        let m = Int(minutesText) ?? 0
                        let s = Double(secondsText) ?? 0.0
                        let total = h * 3600 + m * 60 + Int(s.rounded())
                        guard total > 0 else {
                            errorMessage = String(localized: "lap.error.invalid.time")
                            showingError = true
                            return
                        }
                        onSave(total)
                        dismiss()
                    }
                }
                // Keyboard Done toolbar provided by parent views
            }
            .keyboardDoneToolbar {
                // close keyboard when done
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .alert("common.error", isPresented: $showingError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onAppear {
                let h = initialSeconds / 3600
                let m = (initialSeconds % 3600) / 60
                let s = initialSeconds % 60
                hoursText = String(h)
                minutesText = String(m)
                secondsText = s == 0 ? "0" : String(format: "%.10g", Double(s))
            }
            // Normalization will be handled on submit/save to avoid focus-binding loops.
        }
    }

    private func normalizeEditFields() {
        var h = Int(hoursText) ?? 0
        var m = Int(minutesText) ?? 0
        let sVal = Double(secondsText) ?? 0.0
        let addMinutes = Int(sVal / 60)
        let remainingSeconds = sVal.truncatingRemainder(dividingBy: 60)
        m += addMinutes
        let addHours = m / 60
        h += addHours
        m = m % 60
        hoursText = String(h)
        minutesText = String(m)
        secondsText = String(format: "%.2f", remainingSeconds)
    }
}

/// ラップ追加ビュー
struct AddLapView: View {
    var onAdd: ([LapInput]) -> Void
    var raceType: RaceType
    var totalDistance: Double
    // Optional provider to obtain the most-recent total distance from the parent when
    // the value passed in may be stale due to UI binding timing. Called only when
    // `totalDistance` is 0.0 to avoid overwriting an explicit value.
    var totalDistanceProvider: (() -> Double)? = nil
    var initialLaps: [LapInput]? = nil
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: String = "400m"
    @State private var distanceText: String = ""
    @State private var distanceTextWorkItem: DispatchWorkItem? = nil
    @State private var lapMinutes: [String] = []
    @State private var lapSeconds: [String] = []
    @State private var autoLaps: [LapInput] = []
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var hasInitialized = false
    // Avoid binding a shared FocusState across many UIKit-backed fields.
    // We'll dismiss the keyboard explicitly instead of toggling a shared flag.

    // Treat as edit mode only when an initial laps array with elements is provided.
    // If the parent passes an empty array (common when creating a new race),
    // we should still auto-generate laps instead of treating it as edit mode.
    private var isEditMode: Bool { (initialLaps != nil) && !(initialLaps?.isEmpty ?? true) }
    private func detectPresetFromLaps(_ laps: [LapInput]) -> String {
        guard !laps.isEmpty else { return raceType == .track ? "400m" : "1km" }
        let lapDist = laps[0].distance
        if raceType == .track {
            if abs(lapDist - 0.4) < 0.001 { return "400m" }
            if abs(lapDist - 1.0) < 0.001 { return "1000m" }
            return "custom"
        } else {
            if abs(lapDist - 1.0) < 0.001 { return "1km" }
            if abs(lapDist - 5.0) < 0.001 { return "5km" }
            return "custom"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("lap.preset.section") {
                    if raceType == .track {
                        Picker("lap.preset.picker", selection: $selectedPreset) {
                            Text("400m").tag("400m")
                            Text("1000m").tag("1000m")
                            Text("common.custom").tag("custom")
                        }
                        .pickerStyle(.segmented)
                    } else {
                        Picker("lap.preset.picker", selection: $selectedPreset) {
                            Text("1km").tag("1km")
                            Text("5km").tag("5km")
                            Text("common.custom").tag("custom")
                        }
                        .pickerStyle(.segmented)
                    }
                    if selectedPreset == "custom" {
                        let unitLabel = raceType == .track ? "(m)" : "(km)"
                        TextField(String(format: String(localized: "lap.segment.distance.placeholder %@"), unitLabel), text: $distanceText)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                    }
                }
                Section("lap.input.section") {
                    ForEach(Array(autoLaps.enumerated()), id: \.element.id) { index, lapData in
                        HStack {
                            Text("Lap \(index + 1)")
                            let distanceDisplay = raceType == .track
                                ? String(format: "%.0f", lapData.distance * 1000) + "m"
                                : String(format: "%.2f", lapData.distance) + "km"
                            Text("lap.distance.label") + Text(" \(distanceDisplay)")
                            TextField("common.minute", text: getMinutesBinding(index))
                                .keyboardType(.numberPad)
                                .frame(width: 40)
                                .submitLabel(.done)
                                .onSubmit {
                                    normalizeLapTime(at: index)
                                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                                }
                                .clearZeroOnFocus(getMinutesBinding(index))
                            Text(":")
                            TextField("common.second", text: getSecondsBinding(index))
                                .keyboardType(.decimalPad)
                                .frame(width: 60)
                                .submitLabel(.done)
                                .onSubmit { UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil) }
                                .clearZeroOnFocus(getSecondsBinding(index))
                        }
                    }
                }
                Section {
                    HStack {
                        Text("lap.total.time").fontWeight(.semibold)
                        Spacer()
                        Text(formatTotalTimeDecimal())
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") { addLaps() }
                }
                // Keyboard Done toolbar provided by parent views
            }
            .keyboardDoneToolbar {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
            .alert("common.error", isPresented: $showingError) {
                Button("common.ok", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
            .onChange(of: selectedPreset) { _, _ in updateAutoLaps() }
            .onChange(of: totalDistance) { _, _ in updateAutoLaps() }
            .onChange(of: distanceText) { _, new in
                // カスタム距離の入力中に毎文字で重い再計算を行わないようデバウンス
                guard selectedPreset == "custom" else { return }
                distanceTextWorkItem?.cancel()
                let item = DispatchWorkItem {
                    DispatchQueue.main.async {
                        updateAutoLaps()
                    }
                }
                distanceTextWorkItem = item
                // 0.35秒間入力が止まったら再計算する
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: item)
            }
            .onAppear {
                guard !hasInitialized else { return }
                hasInitialized = true
                if let initialLaps = initialLaps {
                    autoLaps = initialLaps
                    lapMinutes = initialLaps.map { String(Int($0.time) / 60) }
                    lapSeconds = initialLaps.map { String(format: "%.2f", $0.time.truncatingRemainder(dividingBy: 60)) }
                    selectedPreset = detectPresetFromLaps(initialLaps)
                    if selectedPreset == "custom", let firstLap = initialLaps.first {
                        let customDist = raceType == .track ? firstLap.distance * 1000 : firstLap.distance
                        distanceText = String(format: "%.10g", customDist)
                    }
                    } else {
                    // Ensure presets align with race type defaults and generate laps
                    if raceType == .track {
                        // default to 400m when opening editor for track
                        selectedPreset = "400m"
                    } else {
                        selectedPreset = "1km"
                    }

                    // If we have a selected totalDistance (from the parent form),
                    // immediately generate 400m splits for tracks to avoid timing issues.
                    // Use provider if the passed-in `totalDistance` is zero (binding timing issues).
                    let currentTotalOnAppear = totalDistance > 0 ? totalDistance : (totalDistanceProvider?() ?? 0)
                    if raceType == .track && currentTotalOnAppear > 0 {
                        // Only auto-generate when there are no initial laps (avoid overwriting edits)
                        if initialLaps == nil || initialLaps?.isEmpty == true {
                            autoLaps = generate400Splits(totalDistanceKm: currentTotalOnAppear)
                            adjustLapInputSizes(for: autoLaps.count)
                        }
                    } else {
                        // Generate laps immediately based on selected distance
                        updateAutoLaps()
                        // Also schedule a short delayed generation to catch cases where
                        // `totalDistance` or other bindings arrive shortly after presentation.
                        Task {
                            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                            updateAutoLaps()
                        }
                    }

                    // Force generation if still empty: ensure user always sees laps when opening
                    // (only when we're not editing existing laps)
                    if (initialLaps == nil || initialLaps?.isEmpty == true) {
                        if autoLaps.isEmpty {
                            // Try resolving latest total distance
                            let resolved = totalDistance > 0 ? totalDistance : (totalDistanceProvider?() ?? 0)
                            if raceType == .track {
                                // force 400m preset and generate splits when possible
                                selectedPreset = "400m"
                                if resolved > 0 {
                                    autoLaps = generate400Splits(totalDistanceKm: resolved)
                                    adjustLapInputSizes(for: autoLaps.count)
                                } else {
                                    // fallback to updateAutoLaps which may use defaults
                                    updateAutoLaps()
                                }
                            } else {
                                // non-track: try updateAutoLaps
                                updateAutoLaps()
                            }
                        }
                    }
                }
            }
            // Removed focus-based normalization to avoid shared-focus issues.
        }
    }

    private func updateAutoLaps() {
        // Debug: trace when updateAutoLaps is invoked
        print("[LapViews] updateAutoLaps called — selectedPreset=\(selectedPreset) raceType=\(raceType) totalDistance=\(totalDistance)")
        // Resolve current totalDistance: prefer passed-in value, otherwise call provider
        let resolvedTotalDistance = totalDistance > 0 ? totalDistance : (totalDistanceProvider?() ?? 0)
        // totalDistanceが0の場合は、デフォルト距離を使用
        let effectiveTotalDistance = resolvedTotalDistance > 0 ? resolvedTotalDistance : (raceType == .track ? 1.6 : 10.0)
        // 最小許容距離（km単位）。トラックは100m = 0.1km、ロードは0.1kmを最低値とする
        let minAllowedDistanceKm: Double = 0.1
        // 有効総距離が最小未満なら何も生成しない
        guard effectiveTotalDistance >= minAllowedDistanceKm else {
            resetLapInputsIfNeeded()
            autoLaps = []
            return
        }
        
        let lapDist: Double
            if selectedPreset == "custom" {
            guard let customDistance = Double(distanceText), customDistance > 0 else {
                resetLapInputsIfNeeded()
                autoLaps = []
                return
            }
            // customDistance の単位: トラック -> m, ロード -> km
            let maxDistance = raceType == .track ? 10000.0 : 100.0
            let minDistance = raceType == .track ? 100.0 : 0.1
            guard customDistance >= minDistance && customDistance <= maxDistance else {
                resetLapInputsIfNeeded()
                autoLaps = []
                return
            }
            lapDist = raceType == .track ? customDistance / 1000 : customDistance
        } else if raceType == .track {
            if selectedPreset == "400m" {
                lapDist = 0.4
            } else if selectedPreset == "1000m" {
                lapDist = 1.0
            } else {
                lapDist = effectiveTotalDistance
            }
            if !isEditMode { distanceText = "" }
        } else {
            if selectedPreset == "1km" {
                lapDist = 1.0
            } else if selectedPreset == "5km" {
                lapDist = 5.0
            } else {
                lapDist = effectiveTotalDistance
            }
            if !isEditMode { distanceText = "" }
        }
        // lapDist は km 単位になっているため最小値チェックも km 単位で比較
        guard lapDist >= minAllowedDistanceKm && lapDist > 0 && lapDist <= effectiveTotalDistance else {
            resetLapInputsIfNeeded()
            autoLaps = []
            return
        }
        var laps: [LapInput] = []
        var remain = effectiveTotalDistance
        let maxLaps = 1000
        var count = 0
        while remain > 0.0001 && count < maxLaps {
            let d = min(lapDist, remain)
            laps.append(LapInput(distance: d, time: 0))
            remain -= d
            count += 1
        }
        autoLaps = laps
        print("[LapViews] generated \(laps.count) laps, lapDist=\(lapDist)km, effectiveTotalDistance=\(effectiveTotalDistance)km")
        adjustLapInputSizes(for: laps.count)
    }

    /// Generate 400m splits from a total distance (km) — returns laps in km units.
    private func generate400Splits(totalDistanceKm: Double) -> [LapInput] {
        var result: [LapInput] = []
        let totalMeters = Int(round(totalDistanceKm * 1000))
        guard totalMeters >= 100 else { return result }
        let full400 = totalMeters / 400
        let remainder = totalMeters - full400 * 400
        for _ in 0..<full400 {
            result.append(LapInput(distance: 0.4, time: 0))
        }
        if remainder > 0 {
            let remKm = Double(remainder) / 1000.0
            result.append(LapInput(distance: remKm, time: 0))
        }
        print("[LapViews] generate400Splits: totalMeters=\(totalMeters) full=\(full400) remainder=\(remainder) -> \(result.count) laps")
        return result
    }

    private func addLaps() {
        for index in 0..<autoLaps.count {
            let minutes = Double(lapMinutes[index]) ?? 0
            let seconds = Double(lapSeconds[index]) ?? 0
            if minutes * 60 + seconds <= 0 {
                errorMessage = String(format: String(localized: "lap.error.segment.time %lld"), index + 1)
                showingError = true
                return
            }
        }
        var completed: [LapInput] = []
        for (index, lap) in autoLaps.enumerated() {
            let minutes = Double(lapMinutes[index]) ?? 0
            let seconds = Double(lapSeconds[index]) ?? 0
            completed.append(LapInput(distance: lap.distance, time: minutes * 60 + seconds))
        }
        onAdd(completed)
        // Ensure all inputs normalized and keyboard dismissed before closing
        normalizeAllLapTimes()
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        dismiss()
    }

    private func formatTotalTimeDecimal() -> String {
        let total = calculateTotalSecondsDecimal()
        let hours = Int(total) / 3600
        let minutes = (Int(total) % 3600) / 60
        let seconds = total - Double(hours * 3600 + minutes * 60)
        if hours > 0 {
            return String(format: "%d:%02d:%05.2f", hours, minutes, seconds)
        } else {
            return String(format: "%d:%05.2f", minutes, seconds)
        }
    }

    private func calculateTotalSecondsDecimal() -> Double {
        var total: Double = 0
        for index in 0..<autoLaps.count {
            let minutes = Double(lapMinutes.indices.contains(index) ? lapMinutes[index] : "0") ?? 0
            let seconds = Double(lapSeconds.indices.contains(index) ? lapSeconds[index] : "0") ?? 0
            total += minutes * 60 + seconds
        }
        return total
    }

    private func getMinutesBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { lapMinutes.indices.contains(index) ? lapMinutes[index] : "" },
            set: { newValue in
                ensureLapCount(at: index)
                lapMinutes[index] = newValue
            }
        )
    }

    private func getSecondsBinding(_ index: Int) -> Binding<String> {
        Binding(
            get: { lapSeconds.indices.contains(index) ? lapSeconds[index] : "" },
            set: { newValue in
                ensureLapCount(at: index)
                if newValue.isEmpty {
                    lapSeconds[index] = ""
                    return
                }
                // 小数点を含む入力もそのまま保持し、正規化は保存時/表示時に行う
                lapSeconds[index] = newValue
            }
        )
    }

    private func normalizeLapTime(at index: Int) {
        guard index < lapMinutes.count && index < lapSeconds.count else { return }
        let m = Int(lapMinutes[index]) ?? 0
        let s = Double(lapSeconds[index]) ?? 0
        let addMinutes = Int(s / 60)
        let remainingSeconds = s.truncatingRemainder(dividingBy: 60)
        lapMinutes[index] = String(m + addMinutes)
        lapSeconds[index] = remainingSeconds == 0 ? "0" : String(format: "%.2f", remainingSeconds)
    }

    private func normalizeAllLapTimes() {
        for idx in 0..<autoLaps.count { normalizeLapTime(at: idx) }
    }

    private func ensureLapCount(at index: Int) {
        let target = index + 1
        while lapMinutes.count < target { lapMinutes.append("") }
        while lapSeconds.count < target { lapSeconds.append("") }
    }

    private func adjustLapInputSizes(for count: Int) {
        if !isEditMode {
            lapMinutes = Array(repeating: "", count: count)
            lapSeconds = Array(repeating: "", count: count)
        } else if lapMinutes.count != count {
            while lapMinutes.count < count { lapMinutes.append("") }
            while lapSeconds.count < count { lapSeconds.append("") }
        }
    }

    private func resetLapInputsIfNeeded() {
        if !isEditMode {
            lapMinutes = []
            lapSeconds = []
        }
    }
}

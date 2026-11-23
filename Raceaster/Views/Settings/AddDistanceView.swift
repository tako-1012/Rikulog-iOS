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

    private var isField: Bool {
        selectedRaceType == .field
    }

    private var unitLabel: String {
        isTrack ? "m" : "km"
    }
    
    var body: some View {
        NavigationStack {
            Form {
            Section("add.distance.section") {
                TextField("add.distance.name", text: $name)

                // フィールド種目は距離入力不要
                if !isField {
                    AccessoryTextField(text: $distanceValue, placeholder: isTrack ? String(localized: "distance.m.placeholder") : String(localized: "distance.km.placeholder"), keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: true)
                }

                Picker("add.distance.type.picker", selection: $selectedRaceType) {
                    Text("race.type.track").tag(RaceType.track)
                    Text("race.type.road").tag(RaceType.road)
                    Text("race.type.other").tag(RaceType.other)
                    Text("race.type.field").tag(RaceType.field)
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedRaceType) { _, new in
                    distanceValue = ""
                }
            }
            }
            .navigationTitle("add.distance.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.add") {
                        guard !name.isEmpty, name.count <= 50 else {
                            errorMessage = String(localized: "add.distance.error.name")
                            showingError = true
                            return
                        }

                        // フィールド種目はユニークな識別値を自動生成
                        if isField {
                            // 既存フィールド種目の名前重複チェック
                            if existingDistances.contains(where: { $0.raceType == .field && $0.name == name }) {
                                errorMessage = String(localized: "add.distance.error.field.duplicate")
                                showingError = true
                                return
                            }
                            // 既存最大distanceKmから間隔をあけた値を自動生成（±2%で被らないよう100間隔）
                            let maxKm = existingDistances
                                .filter { $0.raceType == .field }
                                .map { $0.distanceKm }
                                .max() ?? 208.0
                            let autoKm = (floor(maxKm / 100.0) + 1) * 100.0
                            let newDistance = RaceDistance(
                                name: name, distanceKm: autoKm, raceType: .field,
                                sortOrder: existingDistances.filter { $0.raceType == .field }.count + 200
                            )
                            modelContext.insert(newDistance)
                            do {
                                try modelContext.save()
                                onAdd(newDistance)
                                dismiss()
                            } catch {
                                errorMessage = String(format: String(localized: "add.distance.error.save %@"), error.localizedDescription)
                                showingError = true
                            }
                            return
                        }

                        guard let value = Double(distanceValue), value > 0 else {
                            errorMessage = String(localized: "add.distance.error.invalid.distance")
                            showingError = true
                            return
                        }

                        let km = isTrack ? value / 1000 : value
                        guard km > 0, km <= 1000 else {
                            let maxValue = isTrack ? "1000000m" : "1000km"
                            errorMessage = String(format: String(localized: "add.distance.error.distance.range %@"), maxValue)
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
                            errorMessage = String(format: String(localized: "add.distance.error.save %@"), error.localizedDescription)
                            showingError = true
                        }
                    }
                }
                // AccessoryTextField provides inputAccessoryView Done button
            }
            .scrollDismissesKeyboard(.interactively)
            .alert("common.error", isPresented: $showingError) {
                Button("common.ok", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .alert("add.distance.duplicate.title", isPresented: $showingDuplicateAlert) {
                Button("add.distance.use.existing") {
                    if let dup = duplicateCandidate {
                        onAdd(dup)
                        dismiss()
                    }
                }
                Button("common.cancel", role: .cancel) { }
            } message: {
                Text(duplicateCandidate.map { String(format: String(localized: "add.distance.duplicate.title"), $0.name) } ?? String(localized: "add.distance.duplicate.title"))
            }
        }
    }
}

#Preview {
    AddDistanceView { _ in }
}

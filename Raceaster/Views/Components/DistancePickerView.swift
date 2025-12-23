import SwiftUI
import SwiftData

struct DistancePickerView: View {
    let raceType: RaceType
    let distances: [RaceDistance]
    @Binding var selectedDistanceId: PersistentIdentifier?
    @Binding var isOtherSelected: Bool
    @Binding var useCustomDistance: Bool
    @Binding var customDistanceText: String
    // allow parent to control whether AccessoryTextField should show its inputAccessoryView
    var accessoryEnabled: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Menu {
                    ForEach(distances.filter { $0.raceType == raceType }, id: \.persistentModelID) { dist in
                        Button(action: {
                            selectedDistanceId = dist.persistentModelID
                            isOtherSelected = false
                            useCustomDistance = false
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(dist.name)
                                    Text(String(format: "%.3f km", dist.distanceKm))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }

                    Button(action: {
                        selectedDistanceId = nil
                        isOtherSelected = true
                        useCustomDistance = true
                    }) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("その他")
                                Text("カスタム距離を入力")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                } label: {
                    HStack {
                        if isOtherSelected {
                            VStack(alignment: .leading) {
                                Text("その他")
                                    .font(.body)
                                if let v = Double(customDistanceText), v > 0 {
                                    Text(String(format: "%.3f km", v))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("種目を選択")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if let selected = distances.first(where: { $0.persistentModelID == selectedDistanceId }) {
                            VStack(alignment: .leading) {
                                Text(selected.name)
                                Text(String(format: "%.3f km", selected.distanceKm))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text("種目を選択")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if let selected = distances.first(where: { $0.persistentModelID == selectedDistanceId }), !isOtherSelected {
                HStack {
                    Text("選択距離: ")
                    Text(String(format: "%.3f km", selected.distanceKm)).bold()
                }
            }

            if useCustomDistance && isOtherSelected {
                HStack {
                    AccessoryTextField(text: $customDistanceText, placeholder: "距離 (km)", keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: accessoryEnabled)
                    Text("km")
                }
            }
        }
    }
}

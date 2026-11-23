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
                                    Text(dist.localizedName)
                                    if !dist.isFieldEvent {
                                        Text(String(format: "%.3f km", dist.distanceKm))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                            }
                        }
                    }

                    // フィールド種目ではカスタム距離入力不要
                    if raceType != .field {
                        Button(action: {
                            selectedDistanceId = nil
                            isOtherSelected = true
                            useCustomDistance = true
                        }) {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text("distance.custom")
                                    Text("distance.custom.input")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                        }
                    }
                } label: {
                    HStack {
                        if isOtherSelected && raceType != .field {
                            VStack(alignment: .leading) {
                                Text("distance.custom")
                                    .font(.body)
                                if let v = Double(customDistanceText), v > 0 {
                                    Text(String(format: "%.3f km", v))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else {
                                    Text("distance.select")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else if let selected = distances.first(where: { $0.persistentModelID == selectedDistanceId }) {
                            VStack(alignment: .leading) {
                                Text(selected.localizedName)
                                if !selected.isFieldEvent {
                                    Text(String(format: "%.3f km", selected.distanceKm))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        } else {
                            VStack(alignment: .leading) {
                                Text("distance.select.event")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // フィールド種目では距離表示行を非表示
            if let selected = distances.first(where: { $0.persistentModelID == selectedDistanceId }),
               !isOtherSelected, !selected.isFieldEvent {
                HStack {
                    Text("distance.selected.label")
                    Text(String(format: "%.3f km", selected.distanceKm)).bold()
                }
            }

            if useCustomDistance && isOtherSelected {
                HStack {
                    AccessoryTextField(text: $customDistanceText, placeholder: String(localized: "distance.km.placeholder"), keyboardType: .decimalPad, isFirstResponder: nil, showAccessory: accessoryEnabled)
                    Text("km")
                }
            }
        }
    }
}

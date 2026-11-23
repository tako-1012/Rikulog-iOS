import SwiftUI

struct LapListSection: View {
    @Binding var laps: [LapInput]
    let raceType: RaceType
    var onEdit: (Int) -> Void

    var body: some View {
        Section {
            ForEach(Array(laps.enumerated()), id: \.element.id) { index, lap in
                Button { onEdit(index) } label: {
                    HStack {
                        Text("Lap \(index + 1)").font(.headline)
                        Spacer()
                        Text("\(String(format: "%.1f", lap.distance))km").foregroundStyle(.secondary)
                        Text(TimeFormatter.formatTime(lap.time)).foregroundStyle(.blue)
                    }
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        laps.remove(at: index)
                    } label: {
                        Label("common.delete", systemImage: "trash")
                    }
                }
            }

            Button {
                onEdit(-1)
            } label: {
                Label("lap.edit", systemImage: "pencil.circle.fill")
            }

            if !laps.isEmpty {
                let totalLapTime = laps.reduce(0.0) { $0 + $1.time }
                HStack {
                    Spacer()
                    Text(String(localized: "lap.section.header") + ": " + TimeFormatter.formatTimeWithFraction(totalLapTime))
                        .font(.headline)
                        .foregroundStyle(.blue)
                    Spacer()
                }
            }
        } header: {
            Text("lap.section.header")
        } footer: {
            Text("lap.section.footer")
        }
    }
}

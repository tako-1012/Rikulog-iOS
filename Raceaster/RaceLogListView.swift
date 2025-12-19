import SwiftUI
import SwiftData

/// レース記録一覧ビュー
struct RaceLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @State private var showingAddSheet = false
    
    var body: some View {
        NavigationStack {
            Group {
                if races.isEmpty {
                    ContentUnavailableView {
                        Label("レース記録なし", systemImage: "list.bullet.rectangle")
                    } description: {
                        Text("右上の＋ボタンからレース記録を追加できます")
                    }
                } else {
                    List {
                        ForEach(races) { race in
                            NavigationLink(destination: RaceDetailView(race: race)) {
                                RaceRowView(race: race)
                            }
                        }
                        .onDelete(perform: deleteRaces)
                    }
                }
            }
            .navigationTitle("レース記録")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddRaceView()
            }
        }
    }
    
    private func deleteRaces(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(races[index])
        }
    }
}

/// レース記録の行ビュー
struct RaceRowView: View {
    let race: RaceRecord
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(race.raceName)
                .font(.headline)
            
            HStack {
                Label("\(race.totalDistance, specifier: "%.1f")km", systemImage: "arrow.left.and.right")
                    .font(.subheadline)
                
                Spacer()
                
                Label(TimeFormatter.formatTime(race.totalTime), systemImage: "timer")
                    .font(.subheadline)
                
                Spacer()
                
                Label(TimeFormatter.formatPace(race.averagePace) + "/km", systemImage: "gauge.medium")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            
            HStack {
                Text(race.date, style: .date)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                Spacer()
                
                Text("VDOT: \(race.vdot, specifier: "%.1f")")
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    RaceLogListView()
        .modelContainer(for: [RaceRecord.self, Lap.self], inMemory: true)
}

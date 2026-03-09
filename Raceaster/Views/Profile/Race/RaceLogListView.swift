import SwiftUI
import SwiftData

/// レース記録一覧ビュー
struct RaceLogListView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @Query(sort: \RaceDistance.sortOrder) private var distances: [RaceDistance]
    @EnvironmentObject var entitlements: AppEntitlements
    @State private var showAddRace = false
    @State private var showLimitAlert = false
    @State private var showPaywall = false
    @State private var selectedDistance: RaceDistance?
    @State private var showDeleteAlert = false
    @State private var raceToDelete: RaceRecord?
    @State private var searchText: String = ""
    private let freeRaceLimit = 50

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 上限警告バナー（45件以上で表示）
                if !entitlements.canUsePremiumFeatures && races.count >= 45 {
                    limitWarningBanner
                }
                
                if displayedRaces.isEmpty {
                    ContentUnavailableView {
                        Label("レース記録なし", systemImage: "figure.run.circle")
                    } description: {
                        Text("初めてのレース記録を追加して\nあなたの走りを記録しましょう！")
                            .multilineTextAlignment(.center)
                    } actions: {
                        Button(action: {
                            if !entitlements.canUsePremiumFeatures && races.count >= freeRaceLimit {
                                showLimitAlert = true
                            } else {
                                showAddRace = true
                            }
                        }) {
                            Label("記録を追加", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(displayedRaces) { race in
                            NavigationLink(destination: RaceDetailView(race: race)) {
                                RaceRowView(race: race)
                            }
                        }
                        .onDelete { indexSet in
                            // 削除確認ダイアログを表示
                            if let idx = indexSet.first {
                                raceToDelete = displayedRaces[idx]
                                showDeleteAlert = true
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .searchable(text: $searchText, prompt: "大会名で検索")
            .navigationTitle("レース記録")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("すべて選択") {
                            selectedDistance = nil
                        }
                        Divider()
                        ForEach(distances) { dist in
                            Button(dist.name) {
                                selectedDistance = dist
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "ruler")
                            Text(selectedDistance?.name ?? "すべて")
                        }
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        if !entitlements.canUsePremiumFeatures && races.count >= freeRaceLimit {
                            showLimitAlert = true
                        } else {
                            showAddRace = true
                        }
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("レース記録を追加")
                }
            }
            .sheet(isPresented: $showAddRace) {
                NavigationStack {
                    AddRaceView()
                }
            }
            .alert("レース登録の上限", isPresented: $showLimitAlert) {
                Button("キャンセル", role: .cancel) { }
                Button("Premiumを見る") {
                    showPaywall = true
                }
            } message: {
                Text("無料版では50件までレースを記録できます。\n\nPremiumにアップグレードすると、無制限にレースを記録できます。")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("記録を削除", isPresented: $showDeleteAlert, presenting: raceToDelete) { race in
                Button("キャンセル", role: .cancel) {
                    raceToDelete = nil
                }
                Button("削除", role: .destructive) {
                    modelContext.delete(race)
                    do {
                        try modelContext.save()
                    } catch {
                        print("⚠️ Failed to delete race: \(error)")
                    }
                    raceToDelete = nil
                }
            } message: { race in
                Text("\"\(race.raceName)\" の記録を削除しますか？\nこの操作は取り消せません。")
            }
        }
    }

    // 上限警告バナー
    private var limitWarningBanner: some View {
        let remaining = max(0, freeRaceLimit - races.count)
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("あと\(remaining)件で上限です")
                    .font(.subheadline.bold())

                if remaining == 0 {
                    Text("これ以上登録するにはPremium版が必要です")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { showPaywall = true }) {
                Text(remaining == 0 ? "Premium版" : "アップグレード")
                    .font(.caption.bold())
            }
            .foregroundColor(.blue)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
    
    }

    private var displayedRaces: [RaceRecord] {
        var result = races
        if let dist = selectedDistance {
            result = result.filter { r in
                dist.matches(distance: r.totalDistance) && r.raceType == dist.raceType
            }
        }
        if !searchText.isEmpty {
            result = result.filter { $0.raceName.localizedCaseInsensitiveContains(searchText) }
        }
        return result
    }
}

/// レース記録の行ビュー
struct RaceRowView: View {
    let race: RaceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: race.raceType.iconName)
                    .foregroundStyle(.blue)
                    .imageScale(.large)
                Text(race.raceName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("距離")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(distanceText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("タイム")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(TimeFormatter.formatTime(race.totalTime, for: race.raceType))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("ペース")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(TimeFormatter.formatPace(race.averagePace) + "/km")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            HStack {
                Text(race.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits).locale(Locale(identifier: "ja_JP"))))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if race.raceType == .track, let meetType = race.trackMeetType {
                    Text(meetType.displayName)
                        .font(.caption2)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple.opacity(0.15))
                        .foregroundStyle(.purple)
                        .cornerRadius(6)
                }

                if let ranking = race.ranking {
                    Text("\(ranking)位")
                        .font(.caption)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(6)
                }

                Spacer()

                Text("VDOT: \(race.vdot, specifier: "%.1f")")
                    .font(.caption)
                    .monospacedDigit()
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.15))
                    .foregroundStyle(.blue)
                    .cornerRadius(6)
            }
        }
        .padding(.vertical, 4)
    }

    private var distanceText: String {
        if race.raceType == .track {
            let meters = Int(race.totalDistance * 1000)
            return "\(meters)m"
        } else {
            return String(format: "%.2f km", race.totalDistance)
        }
    }
}

#Preview {
    RaceLogListView()
        .modelContainer(for: [RaceRecord.self, Lap.self, RaceDistance.self], inMemory: true)
        .environmentObject(AppEntitlements.shared)
}

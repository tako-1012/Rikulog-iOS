import SwiftUI
import SwiftData
import GoogleMobileAds  // 広告表示用

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
                        Label("レース記録なし", systemImage: "figure.run")
                    } description: {
                        Text("初めての記録を追加してみましょう！\n右上の＋ボタンをタップしてください。")
                            .multilineTextAlignment(.center)
                    }
                } else {
                    List {
                        ForEach(displayedRaces) { race in
                            NavigationLink(destination: RaceDetailView(race: race)) {
                                RaceRowView(race: race)
                            }
                        }
                        .onDelete { indexSet in
                            // 削除処理: modelContext を使って削除
                            for idx in indexSet {
                                let race = displayedRaces[idx]
                                modelContext.delete(race)
                                do {
                                    try modelContext.save()
                                } catch {
                                    // 保存に失敗した場合はログ出力
                                    print("Failed to delete race: \(error)")
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
                // 底部にバナー広告を表示（有効な場合）
                if entitlements.shouldShowAds {
                    BannerAdView(
                        adUnitID: BannerAdView.ProductionAdUnitIDs.raceList,
                        adSize: AdSizeBanner
                    )
                    .frame(height: 50)
                    .background(Color(UIColor.systemBackground))
                }

            }
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
        if let dist = selectedDistance {
            return races.filter { r in
                dist.matches(distance: r.totalDistance) && r.raceType == dist.raceType
            }
        }
        return races
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

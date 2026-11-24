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
                        Label("racelog.empty.title", systemImage: "figure.run.circle")
                    } description: {
                        Text("racelog.empty.description")
                            .multilineTextAlignment(.center)
                    } actions: {
                        Button(action: {
                            if !entitlements.canUsePremiumFeatures && races.count >= freeRaceLimit {
                                showLimitAlert = true
                            } else {
                                showAddRace = true
                            }
                        }) {
                            Label("racelog.add.record", systemImage: "plus.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                } else {
                    List {
                        ForEach(displayedRaces) { race in
                            NavigationLink(destination: RaceDetailView(race: race)) {
                                RaceRowView(race: race, eventName: eventName(for: race))
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
            .searchable(text: $searchText, prompt: "racelog.search.prompt")
            .navigationTitle("racelog.title")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("common.all") {
                            selectedDistance = nil
                        }
                        Divider()
                        ForEach(distances) { dist in
                            Button(dist.localizedName) {
                                selectedDistance = dist
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "ruler")
                            Text(selectedDistance?.localizedName ?? String(localized: "racelog.filter.all"))
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
                    .accessibilityLabel("race.add.title")
                }
            }
            .sheet(isPresented: $showAddRace) {
                NavigationStack {
                    AddRaceView()
                }
            }
            .alert("racelog.limit.alert.title", isPresented: $showLimitAlert) {
                Button("common.cancel", role: .cancel) { }
                Button("racelog.premium.button") {
                    showPaywall = true
                }
            } message: {
                Text("racelog.limit.alert.message")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .alert("racelog.delete.title", isPresented: $showDeleteAlert, presenting: raceToDelete) { race in
                Button("common.cancel", role: .cancel) {
                    raceToDelete = nil
                }
                Button("common.delete", role: .destructive) {
                    modelContext.delete(race)
                    do {
                        try modelContext.save()
                    } catch {
                        print("⚠️ Failed to delete race: \(error)")
                    }
                    raceToDelete = nil
                }
            } message: { race in
                Text(String(format: String(localized: "racelog.delete.message %@"), race.raceName))
            }
            #if DEBUG
            .modifier(ScreenshotRaceLogHooks(races: races))
            #endif
        }
    }

    // 上限警告バナー
    private var limitWarningBanner: some View {
        let remaining = max(0, freeRaceLimit - races.count)
        return HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)

            VStack(alignment: .leading, spacing: 4) {
                Text("racelog.limit.warning \(remaining)")
                    .font(.subheadline.bold())

                if remaining == 0 {
                    Text("racelog.premium.needed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button(action: { showPaywall = true }) {
                Text(remaining == 0 ? String(localized: "racelog.premium.limit.button") : String(localized: "racelog.upgrade.button"))
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

    /// フィールド種目の種目名を返す（走種目は nil）
    private func eventName(for race: RaceRecord) -> String? {
        guard race.raceType == .field else { return nil }
        return distances.first { $0.matches(distance: race.totalDistance) && $0.raceType == .field }?.localizedName
    }
}

/// レース記録の行ビュー
struct RaceRowView: View {
    let race: RaceRecord
    /// フィールド種目の種目名（RaceLogListView から渡す）
    var eventName: String? = nil

    var body: some View {
        if race.raceType == .field {
            fieldRowBody
        } else {
            runningRowBody
        }
    }

    // MARK: 走種目（既存UI維持）
    private var runningRowBody: some View {
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
                    Text("race.row.distance")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(distanceText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Divider()
                    .frame(height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text("race.row.time")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(TimeFormatter.formatTime(race.totalTime, for: race.raceType))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("race.row.pace")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(TimeFormatter.formatPace(race.averagePace) + "/km")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
            }

            HStack {
                Text(race.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
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
                    Text(ordinalString(for: ranking))
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

    // MARK: フィールド種目
    private var fieldRowBody: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: race.raceType.iconName)
                    .foregroundStyle(.green)
                    .imageScale(.large)
                Text(race.raceName)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            HStack(spacing: 16) {
                // 種目名
                if let name = eventName {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("race.row.event")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(name)
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    Divider().frame(height: 30)
                }

                // 記録
                VStack(alignment: .leading, spacing: 2) {
                    Text("race.row.record")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(fieldRecordText)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.green)
                }

                Spacer()

                // 追い風参考バッジ
                if race.isWindAided == true {
                    Text("race.row.wind.aided")
                        .font(.caption2)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(6)
                }
            }

            HStack {
                Text(race.date.formatted(.dateTime.year().month(.twoDigits).day(.twoDigits)))
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let ranking = race.ranking {
                    Text(ordinalString(for: ranking))
                        .font(.caption)
                        .monospacedDigit()
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.orange.opacity(0.15))
                        .foregroundStyle(.orange)
                        .cornerRadius(6)
                }

                if let ws = race.windSpeed {
                    Text(String(format: String(localized: "race.wind.format"), ws))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
        }
        .padding(.vertical, 4)
    }

    private var fieldRecordText: String {
        if let fh = race.fieldHeight { return formatFieldRecord(fh) }
        if let fd = race.fieldDistance { return formatFieldRecord(fd) }
        return String(localized: "race.row.no.record")
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

#if DEBUG
/// スクリーンショット撮影モードで詳細・祝福・シェア画面を自動表示する（DEBUG専用）
private struct ScreenshotRaceLogHooks: ViewModifier {
    let races: [RaceRecord]
    @Query private var userProfiles: [UserProfile]
    @State private var detailRace: RaceRecord?
    @State private var celebration: PBCelebration?
    @State private var shareRace: RaceRecord?
    @State private var didPresent = false

    func body(content: Content) -> some View {
        content
            .navigationDestination(item: $detailRace) { RaceDetailView(race: $0) }
            .sheet(item: $celebration) {
                PBCelebrationView(celebration: $0, userProfile: userProfiles.first)
            }
            .sheet(item: $shareRace) { race in
                if let profile = userProfiles.first {
                    ShareRaceView(race: race, userProfile: profile)
                }
            }
            .task(id: races.count) {
                guard ScreenshotMode.isEnabled, !didPresent,
                      let featured = races.first(where: { $0.raceName == ScreenshotMode.featuredRaceName })
                else { return }
                try? await Task.sleep(for: .seconds(1))
                didPresent = true
                switch ScreenshotMode.screen {
                case "detail":
                    detailRace = featured
                case "pb":
                    let previousBest = races
                        .filter { $0.raceType == .track && abs($0.totalDistance - 5.0) < 0.001 && $0.id != featured.id }
                        .map(\.totalTime).min() ?? featured.totalTime
                    celebration = PBCelebration(
                        race: featured,
                        eventName: "5000m",
                        recordText: TimeFormatter.formatTime(featured.totalTime, for: .track),
                        improvementText: PBImprovementFormatter.time(previousBest - featured.totalTime, raceType: .track)
                    )
                case "share":
                    shareRace = featured
                default:
                    break
                }
            }
    }
}
#endif

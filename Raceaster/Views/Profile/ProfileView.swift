import SwiftUI
import SwiftData

// ✅ 型定義を更新：数値としての距離(totalDistance)を追加
struct ShareRecordItem: Identifiable {
    let id = UUID()
    let distanceName: String
    let timeString: String
    let date: Date
    let totalTime: Double
    let totalDistance: Double // ✅ モデルのDouble値をそのまま保持
    let raceType: RaceType
}

struct ProfileView: View {
    @EnvironmentObject var entitlements: AppEntitlements
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    @Query private var userProfiles: [UserProfile]
    
    @State private var showingEditProfile = false
    @State private var showingShareSheet = false

    // PB表示用キャッシュ（races/distances 変化時に .task で非同期再計算）
    @State private var pbDistsByType: [RaceType: [RaceDistance]] = [:]
    @State private var pbFieldDists: [RaceDistance] = []

    private var userProfile: UserProfile { userProfiles.first ?? UserProfile() }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    headerSection
                    statusSection
                    VDOTAverageSection(races: races, userProfile: userProfile)
                    personalBestSection
                    shareCardBannerSection
                    Section("profile.season.best.section") { SeasonBestListView() }
                }
            }
            .navigationTitle("profile.title")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingShareSheet = true }) { Image(systemName: "square.and.arrow.up") }
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                ShareProfileView(
                    userName: userProfile.name,
                    affiliation: userProfile.club,
                    seasonStartMonth: userProfile.seasonStartMonth,
                    allRecords: prepareShareItems()
                )
            }
            .sheet(isPresented: $showingEditProfile) { EditProfileView(profile: userProfile) }
            // races または distances が変わったときだけ PB を再計算する
            // ビュー再描画ではなく、データ変化時のみ実行してメインスレッド負荷を抑える
            .task(id: "\(races.count)-\(distances.count)") {
                await MainActor.run { computePBDistances() }
            }
        }
    }

    /// PB表示に使う種目リストを計算してキャッシュに格納
    private func computePBDistances() {
        for type in [RaceType.track, RaceType.road, RaceType.other] {
            pbDistsByType[type] = distances.filter { d in
                d.raceType == type &&
                races.contains { r in d.matches(distance: r.totalDistance) && r.raceType == d.raceType }
            }.unique().sorted { $0.distanceKm < $1.distanceKm }
        }
        pbFieldDists = distances.filter { d in
            d.raceType == .field &&
            races.contains { r in d.matches(distance: r.totalDistance) && r.raceType == .field }
        }.unique().sorted { $0.sortOrder < $1.sortOrder }
    }

    // ✅ PBセクション：キャッシュ済みリストを使用して描画負荷を排除
    private var personalBestSection: some View {
        Section("profile.pb.section") {
            // 走種目（タイム比較）
            ForEach([RaceType.track, RaceType.road, RaceType.other], id: \.self) { type in
                let validDists = pbDistsByType[type] ?? []
                if !validDists.isEmpty {
                    Text(type.displayName).font(.subheadline).bold().padding(.top, 6)
                    ForEach(validDists) { d in PersonalBestRow(distanceModel: d, races: races, distances: distances) }
                }
            }

            // フィールド種目（記録比較：大きい方が優秀）
            if !pbFieldDists.isEmpty {
                Text(RaceType.field.displayName).font(.subheadline).bold().padding(.top, 6)
                ForEach(pbFieldDists) { d in FieldPersonalBestRow(distanceModel: d, races: races) }
            }
        }
    }

    // ✅ モデルの生の数値を ShareRecordItem に引き継ぐ
    private func prepareShareItems() -> [ShareRecordItem] {
        races.map { r in
            let matchedDistance = distances.first { d in 
                d.matches(distance: r.totalDistance) && d.raceType == r.raceType 
            }
            let name = matchedDistance?.localizedName ?? "\(r.totalDistance)km"
            return ShareRecordItem(
                distanceName: name,
                timeString: TimeFormatter.formatTime(r.totalTime, for: r.raceType),
                date: r.date,
                totalTime: r.totalTime,
                totalDistance: r.totalDistance, // ✅ モデルの数値を保持
                raceType: r.raceType
            )
        }
    }

    private var headerSection: some View {
        Section {
            VStack(alignment: .center, spacing: 12) {
                VStack(spacing: 4) {
                    Text(userProfile.name).font(.title2).bold()
                    if !userProfile.club.isEmpty { Text(userProfile.club).font(.subheadline).foregroundStyle(.secondary) }
                }
                HStack(spacing: 12) {
                    Button(action: { showingEditProfile = true }) {
                        Label("profile.edit", systemImage: "pencil")
                            .font(.callout.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }.buttonStyle(.plain)
                    
                    Button(action: { showingShareSheet = true }) {
                        Label("profile.share.records", systemImage: "square.and.arrow.up")
                            .font(.callout.bold())
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.orange)
                            .foregroundStyle(.white)
                            .cornerRadius(8)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, 4)
            }.frame(maxWidth: .infinity).padding(.vertical, 16)
        }
    }

    private var statusSection: some View {
        Section("profile.status.section") {
            HStack {
                VStack(alignment: .leading) { Text("profile.status.total.records").font(.caption).foregroundStyle(.secondary); Text("\(races.count)").font(.title2).bold().foregroundStyle(.green) }.frame(maxWidth: .infinity)
                Divider().frame(height: 40)
                VStack(alignment: .leading) { Text("profile.status.total.events").font(.caption).foregroundStyle(.secondary); Text("\(distances.count)").font(.title2).bold().foregroundStyle(.blue) }.frame(maxWidth: .infinity)
            }
        }
    }

    private var shareCardBannerSection: some View {
        Section {
            Button(action: { showingShareSheet = true }) {
                HStack(spacing: 12) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(
                            LinearGradient(
                                colors: [.orange, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .cornerRadius(10)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("profile.share.card")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("profile.share.sns")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }
            .buttonStyle(.plain)
        }
    }
}

/// フィールド種目のPB行（記録が大きい方が優秀）
struct FieldPersonalBestRow: View {
    let distanceModel: RaceDistance
    let races: [RaceRecord]

    private var fieldRaces: [RaceRecord] {
        races.filter {
            distanceModel.matches(distance: $0.totalDistance) && $0.raceType == .field
        }
    }

    private var pbRace: RaceRecord? {
        if distanceModel.isHeightEvent {
            return fieldRaces.max { ($0.fieldHeight ?? 0) < ($1.fieldHeight ?? 0) }
        } else {
            return fieldRaces.max { ($0.fieldDistance ?? 0) < ($1.fieldDistance ?? 0) }
        }
    }

    var body: some View {
        if let pb = pbRace {
            let recordValue = pb.fieldHeight ?? pb.fieldDistance ?? 0
            NavigationLink(destination: RaceDetailView(race: pb)) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(distanceModel.localizedName).font(.headline)
                        Text(pb.raceName).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing) {
                        Text(formatFieldRecord(recordValue))
                            .font(.title3).bold().foregroundStyle(.green)
                        Text(pb.date.formatted(date: .numeric, time: .omitted))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.buttonStyle(.plain)
        }
    }
}

struct PersonalBestRow: View {
    let distanceModel: RaceDistance; let races: [RaceRecord]; let distances: [RaceDistance]
    var body: some View {
        if let pb = races.filter({ distanceModel.matches(distance: $0.totalDistance) && $0.raceType == distanceModel.raceType }).min(by: { $0.totalTime < $1.totalTime }) {
            NavigationLink(destination: RaceDetailView(race: pb)) {
                HStack {
                    VStack(alignment: .leading) { Text(distanceModel.localizedName).font(.headline); Text(pb.raceName).font(.caption).foregroundStyle(.secondary) }
                    Spacer()
                        VStack(alignment: .trailing) { 
                        Text(TimeFormatter.formatTime(pb.totalTime, for: pb.raceType)).font(.title3).bold().foregroundStyle(.blue)
                        Text(pb.date.formatted(date: .numeric, time: .omitted)).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.buttonStyle(.plain)
        }
    }
}

struct VDOTAverageSection: View {
    let races: [RaceRecord]; let userProfile: UserProfile
    @State private var selectedPeriod: Int = 90
    @State private var showTrainingPaces: Bool = {
        #if DEBUG
        return ScreenshotMode.isEnabled
        #else
        return false
        #endif
    }()
    var body: some View {
        Section("profile.performance.section") {
            Picker("期間", selection: $selectedPeriod) { Text("profile.period.3months").tag(90); Text("profile.period.6months").tag(180); Text("profile.period.all").tag(9999) }.pickerStyle(.segmented)
            // 短距離（400m 以下）を除外して VDOT を計算
            let cutoffDate = selectedPeriod < 9999 ? Calendar.current.date(byAdding: .day, value: -selectedPeriod, to: Date()) ?? Date() : Date.distantPast
            let validRaces = races.filter { $0.includeInVDOT && $0.totalDistance >= 0.5 && $0.date >= cutoffDate }
            let vdot = validRaces.isEmpty ? 0 : validRaces.reduce(0.0) { $0 + $1.vdot } / Double(validRaces.count)
            HStack {
                VStack(alignment: .leading) { Text("profile.performance.vdot").font(.caption).foregroundStyle(.secondary); Text(String(format: "%.1f", vdot)).font(.title).bold().foregroundStyle(.blue) }
                Spacer()
            }

            // トレーニングペース表示
            if vdot > 0 {
                DisclosureGroup("profile.performance.paces", isExpanded: $showTrainingPaces) {
                    let paces = VDOTCalculator.allTrainingPaces(vdot: vdot)
                    TrainingPaceRow(label: "Easy (E)", pace: paces[.easy] ?? 0, color: .green)
                    TrainingPaceRow(label: "Marathon (M)", pace: paces[.marathon] ?? 0, color: .teal)
                    TrainingPaceRow(label: "Threshold (T)", pace: paces[.threshold] ?? 0, color: .orange)
                    TrainingPaceRow(label: "Interval (I)", pace: paces[.interval] ?? 0, color: .red)
                    TrainingPaceRow(label: "Repetition (R)", pace: paces[.repetition] ?? 0, color: .purple)
                }
            }
        }
    }
}

struct TrainingPaceRow: View {
    let label: String
    let pace: Double
    let color: Color
    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.subheadline)
            Spacer()
            Text(TimeFormatter.formatPace(pace) + " /km")
                .font(.subheadline)
                .fontWeight(.medium)
                .monospacedDigit()
                .foregroundStyle(color)
        }
    }
}

struct EditProfileView: View {
    @Environment(\.dismiss) var dismiss
    @Bindable var profile: UserProfile
    var body: some View {
        NavigationStack {
            Form {
                Section("profile.edit.basic.section") { TextField("profile.edit.name", text: $profile.name); TextField("profile.edit.club", text: $profile.club) }
            }
            .navigationTitle("profile.edit.title").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("common.close") { dismiss() } } }
        }
    }
}
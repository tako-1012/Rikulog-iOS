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
                    Section("シーズンベスト") { SeasonBestListView() }
                }
            }
            .navigationTitle("プロフィール")
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
        }
        .onAppear { }
    }

    // ✅ PBセクション：RaceDistanceの数値(distanceKm)を直接参照してソート
    private var personalBestSection: some View {
        Section("パーソナルベスト") {
            ForEach([RaceType.track, RaceType.road, RaceType.other], id: \.self) { type in
                let validDists = uniqueDistances(
                    distances.filter { d in
                        d.raceType == type && races.contains { r in d.matches(distance: r.totalDistance) && r.raceType == d.raceType }
                    }
                ).sorted { $0.distanceKm < $1.distanceKm }

                if !validDists.isEmpty {
                    Text(type.displayName).font(.subheadline).bold().padding(.top, 6)
                    ForEach(validDists) { d in PersonalBestRow(distanceModel: d, races: races, distances: distances) }
                }
            }
        }
    }

    /// 距離重複を距離kmと種目でユニーク化
    private func uniqueDistances(_ items: [RaceDistance]) -> [RaceDistance] {
        var seen: Set<String> = []
        var result: [RaceDistance] = []
        for d in items {
            let key = "\(d.raceType.rawValue)-\(String(format: "%.6f", d.distanceKm))"
            if !seen.contains(key) {
                seen.insert(key)
                result.append(d)
            }
        }
        return result
    }

    // ✅ モデルの生の数値を ShareRecordItem に引き継ぐ
    private func prepareShareItems() -> [ShareRecordItem] {
        races.map { r in
            let matchedDistance = distances.first { d in 
                d.matches(distance: r.totalDistance) && d.raceType == r.raceType 
            }
            let name = matchedDistance?.name ?? "\(r.totalDistance)km"
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
                        Label("プロフィール編集", systemImage: "pencil")
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
                        Label("記録をシェア", systemImage: "square.and.arrow.up")
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
        Section("ステータス") {
            HStack {
                VStack(alignment: .leading) { Text("総記録数").font(.caption).foregroundStyle(.secondary); Text("\(races.count)").font(.title2).bold().foregroundStyle(.green) }.frame(maxWidth: .infinity)
                Divider().frame(height: 40)
                VStack(alignment: .leading) { Text("登録種目数").font(.caption).foregroundStyle(.secondary); Text("\(distances.count)").font(.title2).bold().foregroundStyle(.blue) }.frame(maxWidth: .infinity)
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
                        Text("共有カードを作成")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("自己ベストをSNSでシェアしよう")
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

struct PersonalBestRow: View {
    let distanceModel: RaceDistance; let races: [RaceRecord]; let distances: [RaceDistance]
    var body: some View {
        if let pb = races.filter({ distanceModel.matches(distance: $0.totalDistance) && $0.raceType == distanceModel.raceType }).min(by: { $0.totalTime < $1.totalTime }) {
            NavigationLink(destination: RaceDetailView(race: pb)) {
                HStack {
                    VStack(alignment: .leading) { Text(distanceModel.name).font(.headline); Text(pb.raceName).font(.caption).foregroundStyle(.secondary) }
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
    @State private var showTrainingPaces: Bool = false
    var body: some View {
        Section("走力指標") {
            Picker("期間", selection: $selectedPeriod) { Text("3ヶ月").tag(90); Text("6ヶ月").tag(180); Text("全データ").tag(9999) }.pickerStyle(.segmented)
            // 短距離（400m 以下）を除外して VDOT を計算
            let cutoffDate = selectedPeriod < 9999 ? Calendar.current.date(byAdding: .day, value: -selectedPeriod, to: Date()) ?? Date() : Date.distantPast
            let validRaces = races.filter { $0.includeInVDOT && $0.totalDistance >= 0.5 && $0.date >= cutoffDate }
            let vdot = validRaces.isEmpty ? 0 : validRaces.reduce(0.0) { $0 + $1.vdot } / Double(validRaces.count)
            HStack {
                VStack(alignment: .leading) { Text("平均VDOT").font(.caption).foregroundStyle(.secondary); Text(String(format: "%.1f", vdot)).font(.title).bold().foregroundStyle(.blue) }
                Spacer()
            }

            // トレーニングペース表示
            if vdot > 0 {
                DisclosureGroup("トレーニングペース", isExpanded: $showTrainingPaces) {
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
                Section("基本情報") { TextField("名前", text: $profile.name); TextField("所属", text: $profile.club) }
            }
            .navigationTitle("プロフィール編集").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } } }
        }
    }
}
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
                ShareProfileView(userName: userProfile.name, affiliation: userProfile.club, allRecords: prepareShareItems())
            }
            .sheet(isPresented: $showingEditProfile) { EditProfileView(profile: userProfile) }
        }
        .onAppear { if userProfiles.isEmpty { modelContext.insert(UserProfile()); try? modelContext.save() } }
    }

    // ✅ PBセクション：RaceDistanceの数値(distanceKm)を直接参照してソート
    private var personalBestSection: some View {
        Section("パーソナルベスト") {
            ForEach([RaceType.track, RaceType.road, RaceType.other], id: \.self) { type in
                let validDists = distances
                    .filter { d in d.raceType == type && races.contains { r in d.matches(distance: r.totalDistance) && r.raceType == d.raceType } }
                    .sorted { $0.distanceKm < $1.distanceKm } // ✅ 数値でソート
                
                if !validDists.isEmpty {
                    Text(type.displayName).font(.subheadline).bold().padding(.top, 6)
                    ForEach(validDists) { d in PersonalBestRow(distanceModel: d, races: races, distances: distances) }
                }
            }
        }
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
                Button(action: { showingEditProfile = true }) {
                    Label("プロフィール編集", systemImage: "pencil").font(.callout).padding(.horizontal, 16).padding(.vertical, 10).background(Color.blue).foregroundStyle(.white).cornerRadius(8)
                }.buttonStyle(.plain)
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
    var body: some View {
        Section("走力指標") {
            Picker("期間", selection: $selectedPeriod) { Text("3ヶ月").tag(90); Text("6ヶ月").tag(180); Text("全データ").tag(9999) }.pickerStyle(.segmented)
            let vdot = races.isEmpty ? 0 : races.filter { $0.includeInVDOT }.reduce(0.0) { $0 + $1.vdot } / Double(max(1, races.filter { $0.includeInVDOT }.count))
            HStack {
                VStack(alignment: .leading) { Text("平均VDOT").font(.caption).foregroundStyle(.secondary); Text(String(format: "%.1f", vdot)).font(.title).bold().foregroundStyle(.blue) }
                Spacer()
            }
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
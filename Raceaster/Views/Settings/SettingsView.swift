import SwiftUI
import SwiftData

/// 設定画面ビュー
struct SettingsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceDistance.distanceKm) private var distances: [RaceDistance]
    @Query private var userProfiles: [UserProfile]
    @Query(sort: \RaceRecord.date, order: .reverse) private var races: [RaceRecord]
    @EnvironmentObject var entitlements: AppEntitlements
    @State private var showingPrivacyPolicy = false
    @State private var showingTerms = false
    @State private var showingInitError = false
    @State private var initErrorMessage = ""
    @State private var seasonStartMonthState: Int = 4
    @State private var seasonEndMonthState: Int = 3
    @State private var showPaywall = false
    @AppStorage("notificationFrequency") private var notificationFrequency: String = NotificationFrequency.weekly.rawValue
    
    // 通知頻度を取得
    private var selectedFrequency: NotificationFrequency {
        get { NotificationFrequency(rawValue: notificationFrequency) ?? .weekly }
        set { notificationFrequency = newValue.rawValue }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // iCloud 同期表示を削除
                    Section {
                        NavigationLink(destination: RaceDistanceManagementView()) {
                            Label("settings.events.management", systemImage: "list.number")
                        }
                    } header: {
                        Text("settings.events.section")
                    } footer: {
                        Text("settings.events.footer \(distances.count)")
                    }

                    Section("settings.app.info") {
                        HStack {
                            Label("settings.version", systemImage: "info.circle")
                            Spacer()
                            Text(appVersion).foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("settings.build", systemImage: "hammer")
                            Spacer()
                            Text(buildNumber).foregroundStyle(.secondary)
                        }
                    }

                    usageSection

                    // Premium セクション
                    Section {
                        if entitlements.hasPremium {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                                Text("settings.premium.member").font(.headline)
                                Spacer()
                                Text("✨")
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("settings.premium.upgrade").font(.headline).foregroundColor(.primary)
                                        Text("settings.premium.unlock").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                    } header: { Text("settings.premium.section") }

                    Section("settings.other.section") {
                        Button(action: { openContactForm() }) {
                            Label("settings.contact", systemImage: "envelope").foregroundStyle(.primary)
                        }
                        Button(action: { showingPrivacyPolicy = true }) {
                            Label("settings.privacy", systemImage: "hand.raised").foregroundStyle(.primary)
                        }
                        Button(action: { showingTerms = true }) {
                            Label("settings.terms", systemImage: "doc.text").foregroundStyle(.primary)
                        }
                    }

                    Section {
                        Picker("settings.notifications.picker", selection: Binding(
                            get: { selectedFrequency },
                            set: { newValue in
                                notificationFrequency = newValue.rawValue
                                NotificationManager.shared.currentFrequency = newValue
                            }
                        )) {
                            ForEach(NotificationFrequency.allCases) { frequency in
                                Text(frequency.displayName).tag(frequency)
                            }
                        }
                    } header: {
                        Text("settings.notifications.section")
                    } footer: {
                        Text("settings.notifications.footer")
                    }

                    Section {
                        Picker("settings.season.start", selection: $seasonStartMonthState) {
                            ForEach(Array(1...12), id: \.self) { Text(Calendar.current.shortStandaloneMonthSymbols[$0 - 1]).tag($0) }
                        }
                        LabeledContent("settings.season.end") {
                            let endMonth = seasonStartMonthState == 1 ? 12 : seasonStartMonthState - 1
                            Text(Calendar.current.shortStandaloneMonthSymbols[endMonth - 1])
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("settings.season.section")
                    } footer: {
                        Text("settings.season.footer")
                    }

                    // (Manual dedupe button removed; automatic dedupe runs at startup.)
                }

            }
            .navigationTitle("settings.title")
            .sheet(isPresented: $showingPrivacyPolicy) {
                if let url = URL(string: "https://tako-1012.github.io/riku-log_policies/privacy-policy.html") {
                    SafariView(url: url)
                } else {
                    PrivacyPolicyView()
                }
            }
            .sheet(isPresented: $showingTerms) {
                if let url = URL(string: "https://tako-1012.github.io/riku-log_policies/terms.html") {
                    SafariView(url: url)
                } else {
                    TermsOfServiceView()
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .onAppear {
            if let profile = userProfiles.first {
                seasonStartMonthState = profile.seasonStartMonth
                seasonEndMonthState = profile.seasonEndMonth
            }
            // Ensure default distances exist (insert only missing items)
            let defaults = RaceDistance.createDefaultDistances()
            var inserted = 0
            for distance in defaults {
                let exists = distances.contains { existing in
                    abs(existing.distanceKm - distance.distanceKm) < 0.0001 && existing.raceType == distance.raceType && existing.name == distance.name
                }
                if !exists { modelContext.insert(distance); inserted += 1 }
            }
            if inserted > 0 {
                do { try modelContext.save() } catch {
                    initErrorMessage = String(format: String(localized: "settings.error.init %@"), error.localizedDescription)
                    showingInitError = true
                }
            }
        }
        .alert("settings.init.error", isPresented: $showingInitError) { Button("common.ok", role: .cancel) { } } message: { Text(initErrorMessage) }
        .onChange(of: seasonStartMonthState) { _, new in
            guard let profile = userProfiles.first else { return }
            profile.seasonStartMonth = new
            // 終了月を自動計算（開始月の前月）
            let endMonth = new == 1 ? 12 : new - 1
            profile.seasonEndMonth = endMonth
            do { try modelContext.save() } catch {
                initErrorMessage = String(format: String(localized: "settings.error.season %@"), error.localizedDescription)
                showingInitError = true
            }
        }

    }

    
    private func openContactForm() {
        if let url = URL(string: "https://forms.gle/WjgUoe6pMNt6zcdp8") { UIApplication.shared.open(url) }
    }
}



// MARK: - SettingsView Sections
extension SettingsView {
    // iCloud 表示は削除

    private var usageSection: some View {
        Section { raceUsageRow } header: { Text("settings.usage.section") }
    }

    private var raceUsageRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("settings.usage.race").font(.body)
                if entitlements.canUsePremiumFeatures {
                    Text("settings.usage.unlimited").font(.caption).foregroundColor(.green)
                } else {
                    Text("settings.usage.count \(races.count)").font(.caption).foregroundColor(races.count >= 45 ? .orange : .secondary)
                }
            }
            Spacer()
            if !entitlements.canUsePremiumFeatures {
                ProgressView(value: Double(races.count), total: 50.0).frame(width: 100)
            }
        }
    }
    
    // MARK: - Bundle情報の取得
    /// Bundle.mainからアプリバージョンを取得
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
    }
    
    /// Bundle.mainからビルド番号を取得
    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
    }
}

// MARK: - 種目管理画面
struct RaceDistanceManagementView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \RaceDistance.distanceKm) private var allDistances: [RaceDistance]
    @Query private var allRaces: [RaceRecord]
    @EnvironmentObject var entitlements: AppEntitlements

    @State private var showingAddSheet = false
    @State private var showingDeleteAlert = false
    @State private var distanceToDelete: RaceDistance?
    @State private var relatedRacesCount = 0

    var body: some View {
        List {
            // Display order: Track, Road, Other, Field
            ForEach([RaceType.track, RaceType.road, RaceType.other, RaceType.field], id: \.self) { raceType in
                Section(raceType.displayName) {
                    let filteredDistances = allDistances.filter { $0.raceType == raceType && !isDeletedDistance($0) }
                    if filteredDistances.isEmpty {
                        Text("event.management.empty").foregroundStyle(.secondary).italic()
                    } else {
                        ForEach(filteredDistances) { distance in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(distance.localizedName).font(.headline)
                                    if !distance.isFieldEvent {
                                        (Text("settings.event.distance.label") + Text(" \(String(format: "%.3f", distance.distanceKm)) km")).font(.subheadline).foregroundStyle(.secondary)
                                    } else if let sub = distance.subcategoryRaw {
                                        Text(sub == "jump" ? String(localized: "event.management.jump") : String(localized: "event.management.throw")).font(.subheadline).foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    relatedRacesCount = allRaces.filter { race in
                                        distance.matches(distance: race.totalDistance) && race.raceType == distance.raceType
                                    }.count
                                    distanceToDelete = distance
                                    showingDeleteAlert = true
                                } label: { Image(systemName: "trash").foregroundStyle(.red) }.buttonStyle(.plain)
                            }
                        }
                    }
                    Button(action: { showingAddSheet = true }) { Label("event.management.add", systemImage: "plus.circle.fill") }
                }
            }
        }
        .onAppear {
            Task { await performManagementViewAutoDedupe() }
        }
        .navigationTitle("event.management.title")
        .sheet(isPresented: $showingAddSheet) { AddDistanceView { _ in } }
        .alert("event.management.delete.title", isPresented: $showingDeleteAlert, presenting: distanceToDelete) { distance in
            Button("common.cancel", role: .cancel) { }
            Button("common.delete", role: .destructive) { deleteDistance(distance) }
        } message: { distance in
            if relatedRacesCount > 0 {
                Text(String(format: String(localized: "event.delete.with.races.message %@ %lld"), distance.localizedName, relatedRacesCount))
            } else {
                Text(String(format: String(localized: "event.delete.no.races.message %@"), distance.localizedName))
            }
        }
    }

    private func deleteDistance(_ distance: RaceDistance) {
        // まず削除したデフォルト種目を記録して、再起動時に復活しないようにする
        recordDeletedDefaultDistance(distance)
        
        // データベースから削除
        modelContext.delete(distance)
        do {
            try modelContext.save()
            print("Successfully deleted distance: \(distance.name)")
        } catch {
            print("Failed to delete distance: \(error.localizedDescription)")
        }
    }
    
    private func recordDeletedDefaultDistance(_ distance: RaceDistance) {
        let key = "deletedDefaultDistances"
        var deletedIds = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        
        // 削除した種目の情報を記録（距離とレースタイプで一意に識別）
        let entry: [String: Any] = [
            "distanceKm": distance.distanceKm,
            "raceType": distance.raceType.rawValue,
            "name": distance.name
        ]
        
        // 重複を避ける
        if !deletedIds.contains(where: { dict in
            let dkm = dict["distanceKm"] as? Double ?? 0
            let rtype = dict["raceType"] as? String ?? ""
            let dname = dict["name"] as? String ?? ""
            return abs(dkm - distance.distanceKm) < 0.0001 && rtype == distance.raceType.rawValue && dname == distance.name
        }) {
            deletedIds.append(entry)
            UserDefaults.standard.set(deletedIds, forKey: key)
        }
    }
    
    private static func isDefaultDistanceDeleted(_ distance: RaceDistance) -> Bool {
        let key = "deletedDefaultDistances"
        let deletedIds = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        
        return deletedIds.contains { dict in
            let dkm = dict["distanceKm"] as? Double ?? 0
            let rtype = dict["raceType"] as? String ?? ""
            let dname = dict["name"] as? String ?? ""
            return abs(dkm - distance.distanceKm) < 0.0001 && rtype == distance.raceType.rawValue && dname == distance.name
        }
    }

    @MainActor
    private func performManagementViewAutoDedupe() async {
        let deleted = RaceDistanceDeduplicator.deduplicateDistances(allDistances, in: modelContext)
        if deleted > 0 { print("ManagementView auto dedupe completed. Deleted \(deleted) duplicate RaceDistance entries.") }
    }
    
    private func isDeletedDistance(_ distance: RaceDistance) -> Bool {
        let key = "deletedDefaultDistances"
        let deletedIds = UserDefaults.standard.array(forKey: key) as? [[String: Any]] ?? []
        
        return deletedIds.contains { dict in
            let dkm = dict["distanceKm"] as? Double ?? 0
            let rtype = dict["raceType"] as? String ?? ""
            let dname = dict["name"] as? String ?? ""
            return abs(dkm - distance.distanceKm) < 0.0001 && rtype == distance.raceType.rawValue && dname == distance.name
        }
    }
}

// MARK: - プライバシーポリシー（全文復元）
struct PrivacyPolicyView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("プライバシーポリシー").font(.title2).bold()
                        PolicySection(title: "1. 個人情報の収集", content: "本アプリは、ユーザーが入力したレース記録やプロフィール情報をデバイス内のみに保存します。外部サーバーへの送信は行いません。")
                        PolicySection(title: "2. 情報の利用", content: "収集した情報は、VDOT計算や統計情報の表示など、アプリの機能提供のみに使用されます。")
                        PolicySection(title: "3. 情報の保護", content: "ユーザーの情報はデバイス内のSwiftDataに安全に保存されます。")
                        PolicySection(title: "4. 情報の削除", content: "ユーザーはいつでもアプリ内からレース記録やプロフィール情報を削除できます。")
                        PolicySection(title: "5. 変更について", content: "本ポリシーは予告なく変更される場合があります。")
                    }.padding()
                }
            }
            .navigationTitle("privacy.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("common.done") { dismiss() } } }
        }
    }
}

// MARK: - 利用規約（全文復元）
struct TermsOfServiceView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("利用規約").font(.title2).bold()
                        PolicySection(title: "1. 利用について", content: "本アプリは個人的なランニング記録管理の目的で使用してください。")
                        PolicySection(title: "2. 免責事項", content: "本アプリで計算されたVDOTやペースは参考情報です。医学的または医療的なアドバイスではありません。")
                        PolicySection(title: "3. ユーザーの責任", content: "ユーザーはアプリの使用に関する全ての責任を負うものとします。アプリの使用によって生じた損害について、開発者は責任を負いません。")
                        PolicySection(title: "4. 禁止事項", content: "本アプリを営利目的で利用すること、不正な方法でアクセスすること、他人のデータを改ざんすることを禁止します。")
                        PolicySection(title: "5. サービスの変更・廃止", content: "本アプリのサービスは予告なく変更・廃止される場合があります。")
                        PolicySection(title: "6. 準拠法", content: "本規約は日本法に準拠し、日本の裁判所の専属的管轄に服するものとします。")
                    }.padding()
                }
            }
            .navigationTitle("terms.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("common.done") { dismiss() } } }
        }
    }
}

struct PolicySection: View {
    let title: String; let content: String
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            Text(content).font(.body)
        }
    }
}
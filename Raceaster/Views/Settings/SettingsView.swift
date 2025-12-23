import SwiftUI
import SwiftData
import GoogleMobileAds

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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    // iCloud 同期表示を削除
                    Section {
                        NavigationLink(destination: RaceDistanceManagementView()) {
                            Label("種目管理", systemImage: "list.number")
                        }
                    } header: {
                        Text("種目設定")
                    } footer: {
                        Text("登録済み種目: \(distances.count)件")
                    }

                    Section("アプリ情報") {
                        HStack {
                            Label("バージョン", systemImage: "info.circle")
                            Spacer()
                            Text("1.0.0").foregroundStyle(.secondary)
                        }
                        HStack {
                            Label("ビルド", systemImage: "hammer")
                            Spacer()
                            Text("2025.12.08").foregroundStyle(.secondary)
                        }
                    }

                    usageSection

                    // Premium セクション
                    Section {
                        if entitlements.hasPremium {
                            HStack {
                                Image(systemName: "checkmark.seal.fill").foregroundColor(.blue)
                                Text("Premium会員").font(.headline)
                                Spacer()
                                Text("✨")
                            }
                        } else {
                            Button {
                                showPaywall = true
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Premiumにアップグレード").font(.headline).foregroundColor(.primary)
                                        Text("すべての機能を解放").font(.caption).foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "arrow.right.circle.fill").foregroundColor(.blue)
                                }
                            }
                        }
                    } header: { Text("Premium") }

                    Section("その他") {
                        Button(action: { openContactForm() }) {
                            Label("お問い合わせ・バグ報告", systemImage: "envelope").foregroundStyle(.primary)
                        }
                        Button(action: { showingPrivacyPolicy = true }) {
                            Label("プライバシーポリシー", systemImage: "hand.raised").foregroundStyle(.primary)
                        }
                        Button(action: { showingTerms = true }) {
                            Label("利用規約", systemImage: "doc.text").foregroundStyle(.primary)
                        }
                    }

                    Section {
                        Picker("シーズン開始月", selection: $seasonStartMonthState) {
                            ForEach(Array(1...12), id: \.self) { Text("\($0)月").tag($0) }
                        }
                        Picker("シーズン終了月", selection: $seasonEndMonthState) {
                            ForEach(Array(1...12), id: \.self) { Text("\($0)月").tag($0) }
                        }
                    } header: {
                        Text("シーズン設定")
                    } footer: {
                        Text("シーズンの開始・終了月を設定します（例: 4月開始 → 4月 - 翌年3月）。")
                    }

                    // (Manual dedupe button removed; automatic dedupe runs at startup.)
                }

                if entitlements.shouldShowAds {
                    BannerAdView(adUnitID: BannerAdView.ProductionAdUnitIDs.settings, adSize: AdSizeBanner)
                        .frame(height: 50)
                        .background(Color.gray.opacity(0.1))
                }
            }
            .navigationTitle("設定")
            .sheet(isPresented: $showingPrivacyPolicy) {
                if let url = URL(string: "https://tako-1012.github.io/riku-log-policies/privacy-policy.html") {
                    SafariView(url: url)
                } else {
                    PrivacyPolicyView()
                }
            }
            .sheet(isPresented: $showingTerms) {
                if let url = URL(string: "https://tako-1012.github.io/riku-log-policies/terms.html") {
                    SafariView(url: url)
                } else {
                    TermsOfServiceView()
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
        .onAppear {
            if userProfiles.isEmpty {
                let newProfile = UserProfile()
                modelContext.insert(newProfile)
                do { try modelContext.save() } catch {
                    initErrorMessage = "ユーザープロファイル作成に失敗しました: \(error.localizedDescription)"
                    showingInitError = true
                }
            }
            if let profile = userProfiles.first {
                seasonStartMonthState = profile.seasonStartMonth
                seasonEndMonthState = profile.seasonEndMonth
            }
            // Ensure default distances exist (insert only missing items)
            let defaults = RaceDistance.createDefaultDistances()
            var inserted = 0
            for distance in defaults {
                let exists = distances.contains { existing in
                    abs(existing.distanceKm - distance.distanceKm) < 0.0001 && existing.raceType == distance.raceType
                }
                if !exists { modelContext.insert(distance); inserted += 1 }
            }
            if inserted > 0 {
                do { try modelContext.save() } catch {
                    initErrorMessage = "デフォルト種目の作成に失敗しました: \(error.localizedDescription)"
                    showingInitError = true
                }
            }
        }
        .alert("初期化エラー", isPresented: $showingInitError) { Button("OK", role: .cancel) { } } message: { Text(initErrorMessage) }
        .onChange(of: seasonStartMonthState) { _, new in
            guard let profile = userProfiles.first else { return }
            profile.seasonStartMonth = new
            do { try modelContext.save() } catch {
                initErrorMessage = "シーズン開始月の保存に失敗しました: \(error.localizedDescription)"
                showingInitError = true
            }
        }
        .onChange(of: seasonEndMonthState) { _, new in
            guard let profile = userProfiles.first else { return }
            profile.seasonEndMonth = new
            do { try modelContext.save() } catch {
                initErrorMessage = "シーズン終了月の保存に失敗しました: \(error.localizedDescription)"
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
        Section { raceUsageRow } header: { Text("使用状況") }
    }

    private var raceUsageRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("レース記録").font(.body)
                if entitlements.canUsePremiumFeatures {
                    Text("無制限").font(.caption).foregroundColor(.green)
                } else {
                    Text("\(races.count)/50件").font(.caption).foregroundColor(races.count >= 45 ? .orange : .secondary)
                }
            }
            Spacer()
            if !entitlements.canUsePremiumFeatures {
                ProgressView(value: Double(races.count), total: 50.0).frame(width: 100)
            }
        }
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
            // Display order: Track first, then Road, then Other
            ForEach([RaceType.track, RaceType.road, RaceType.other], id: \.self) { raceType in
                Section(raceType.displayName) {
                    let filteredDistances = allDistances.filter { $0.raceType == raceType }
                    if filteredDistances.isEmpty {
                        Text("種目が登録されていません").foregroundStyle(.secondary).italic()
                    } else {
                        ForEach(filteredDistances) { distance in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(distance.name).font(.headline)
                                    Text("距離: \(String(format: "%.3f", distance.distanceKm)) km").font(.subheadline).foregroundStyle(.secondary)
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
                    Button(action: { showingAddSheet = true }) { Label("種目を追加", systemImage: "plus.circle.fill") }
                }
            }
        }
        .onAppear {
            Task { await performManagementViewAutoDedupe() }
        }
        .navigationTitle("種目管理")
        .sheet(isPresented: $showingAddSheet) { AddDistanceView { _ in } }
        .alert("種目を削除", isPresented: $showingDeleteAlert, presenting: distanceToDelete) { distance in
            Button("キャンセル", role: .cancel) { }
            Button("削除", role: .destructive) { deleteDistance(distance) }
        } message: { distance in
            if relatedRacesCount > 0 {
                Text("この種目（\(distance.name)）を使用している\(relatedRacesCount)件のレース記録が存在します。\n\n種目を削除してもレース記録は残りますが、種目名が表示されなくなります。本当に削除しますか？")
            } else {
                Text("\(distance.name)を削除しますか？\n\nこの種目を使用しているレース記録はありません。")
            }
        }
    }

    private func deleteDistance(_ distance: RaceDistance) {
        modelContext.delete(distance)
        try? modelContext.save()
    }

    @MainActor
    private func performManagementViewAutoDedupe() async {
        let all = allDistances
        var groups: [String: [RaceDistance]] = [:]
        for d in all {
            let key = "\(d.raceType.rawValue)-\(String(format: "%.6f", d.distanceKm))"
            groups[key, default: []].append(d)
        }

        var deleted = 0
        for (_, items) in groups {
            if items.count <= 1 { continue }
            let duplicates = items.dropFirst()
            for dup in duplicates {
                modelContext.delete(dup)
                deleted += 1
            }
        }

        do { try modelContext.save() } catch { print("ManagementView auto-dedupe save failed: \(error)") }
        if deleted > 0 { print("ManagementView auto dedupe completed. Deleted \(deleted) duplicate RaceDistance entries.") }
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
            .navigationTitle("プライバシーポリシー")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } } }
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
            .navigationTitle("利用規約")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("完了") { dismiss() } } }
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
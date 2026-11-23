import SwiftUI
import SwiftData
import GoogleMobileAds
import AppTrackingTransparency
import CloudKit
import UserNotifications

@main
struct RaceMasterApp: App {
    @StateObject private var entitlements = AppEntitlements.shared
    @StateObject private var storeKitManager = StoreKitManager.shared

    init() {
        // AdMob初期化
        MobileAds.shared.start { status in
            print("✅ AdMob initialized")
            print("AdMob initialization status: \(status)")
        }

        // キーボード処理（無効化：各ViewでのsimultaneousGesture実装へ移行）
        // DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        //     UIApplication.shared.enableKeyboardDismissOnTap()
        // }

        // ATT（追跡許可）を1秒後に要求
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            RaceMasterApp.requestTrackingAuthorization()
        }

        // 月末リマインダーのローカル通知を準備
        NotificationManager.shared.ensureMonthEndReminderScheduled()

        // 起動時のエントitlements と 購入状態をログ出力（実機デバッグ用）
        DispatchQueue.main.async {
            #if DEBUG
            print("🔎 AppEntitlements.shouldShowAds = \(AppEntitlements.shared.shouldShowAds)")
            print("🔎 StoreKitManager.isPremium: \(StoreKitManager.shared.isPremium)")
            #endif
        }

        // 起動直後に RaceDistance の重複を除去（TabView 描画前に実施）
        earlyAutoDedupeRaceDistances()

        // DB初期化・マイグレーション（init()完了後に非同期実行してメインスレッドをブロックしない）
        let container = sharedModelContainer
        Task { AppInitializer.run(in: container) }
    }

    // ATT リクエスト関数
    private static func requestTrackingAuthorization() {
        if #available(iOS 14, *) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    print("✅ Tracking authorized")
                case .denied:
                    print("ℹ️ Tracking denied")
                case .notDetermined:
                    print("ℹ️ Tracking not determined")
                case .restricted:
                    print("ℹ️ Tracking restricted")
                @unknown default:
                    print("ℹ️ Unknown tracking status")
                }
            }
        }
    }

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            RaceRecord.self,
            Lap.self,
            RaceDistance.self,
            UserProfile.self,
        ])
        // ✅ CloudKit（iCloud）同期を有効化（アプリ側で iCloud capability を追加済み）
        // コンテナ識別子は Xcode で設定したものと一致させる
        // 一部のSDKでは CloudKitConfiguration 型が見つからないため、
        // container identifier を直接渡す初期化子を使う（利用可能な場合）。
        // CloudKit の初期化は SDK により初期化子と型が異なるため、
        // 現在の環境ではシンプルな ModelConfiguration を使って起動します。
        // CloudKit を開発環境で強制有効化するには利用中の Xcode/SDK の
        // `ModelConfiguration` 初期化子の正確なシグネチャを使用する必要があります。
        let modelConfiguration: ModelConfiguration
        // Check CloudKit availability first. If the user's iCloud account is not
        // available (or check times out), fall back to a local-only configuration
        // to avoid repeated "Bad Container" errors at startup.
        var enableCloudKit = false
        if #available(iOS 17.0, *) {
            let ck = CKContainer(identifier: "iCloud.com.kotaro.riku-log")
            var status: CKAccountStatus = .couldNotDetermine
            let sem = DispatchSemaphore(value: 0)
            ck.accountStatus { s, _ in
                status = s
                sem.signal()
            }
            // wait up to 0.5 seconds for account status (short timeout to avoid Watchdog kill)
            _ = sem.wait(timeout: .now() + 0.5)
            if status == .available {
                enableCloudKit = true
            }
        }

        if enableCloudKit {
            modelConfiguration = ModelConfiguration(
                "iCloud.com.kotaro.riku-log",
                schema: schema,
                isStoredInMemoryOnly: false,
                allowsSave: true,
                groupContainer: .automatic,
                cloudKitDatabase: .automatic
            )
            print("✅ CloudKit account available — using CloudKit-backed ModelConfiguration")
        } else {
            modelConfiguration = ModelConfiguration(
                schema: schema,
                isStoredInMemoryOnly: false
            )
            print("⚠️ CloudKit unavailable or not signed in — falling back to local-only ModelConfiguration")
        }

        do {
            let container = try ModelContainer(
                for: schema,
                configurations: [modelConfiguration]
            )
            print("✅ ModelContainer initialized (CloudKit attempt). CloudKit database: private if supported")

            // 衝突解決: configure merge policy when using CloudKit-backed
            // persistence. This requires the SDK/runtime that exposes
            // persistence settings on ModelContainer.

            return container
        } catch {
            print("❌ CloudKit ModelContainer failed: \(error.localizedDescription). Falling back to local-only.")
            print("Error details: \(error)")
            // CloudKit失敗時はローカルのみで起動（ユーザーデータは保持される）
            do {
                let fallbackConfig = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false
                )
                let fallbackContainer = try ModelContainer(
                    for: schema,
                    configurations: [fallbackConfig]
                )
                print("✅ Fallback local-only ModelContainer created successfully")
                return fallbackContainer
            } catch {
                print("❌ Even local-only ModelContainer failed: \(error)")
                fatalError("Could not create even local ModelContainer: \(error)")
            }
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            if storeKitManager.isLoading {
                // 起動時にStoreKitの状態が確定するまで短時間待機
                // キャッシュがあれば通常は非常に短時間（数ms）で解除される
                ZStack {
                    Color(UIColor.systemBackground)
                        .ignoresSafeArea()
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "stopwatch.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.blue)
                        Text("app.name")
                            .font(.title)
                            .fontWeight(.bold)
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.2)
                        Text("app.loading")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                            .frame(height: 60)
                    }
                }
            } else {
                MainTabView()
                    .environmentObject(entitlements)
                    .environmentObject(storeKitManager)
            }
        }
        .modelContainer(sharedModelContainer)
    }
}

// MARK: - Early Dedupe
extension RaceMasterApp {
    /// App起動直後に `RaceDistance` の重複エントリを除去する。
    private func earlyAutoDedupeRaceDistances() {
        let deleted = RaceDistanceDeduplicator.deduplicateDistances(in: sharedModelContainer)
        if deleted > 0 {
            print("Early auto dedupe completed. Deleted \(deleted) duplicate RaceDistance entries before UI.")
        }
    }
}

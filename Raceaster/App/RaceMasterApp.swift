import SwiftUI
import SwiftData
import GoogleMobileAds
import AppTrackingTransparency
import CloudKit

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

        // 起動時のエントitlements と 購入状態をログ出力（実機デバッグ用）
        DispatchQueue.main.async {
            #if DEBUG
            print("🔎 AppEntitlements.shouldShowAds = \(AppEntitlements.shared.shouldShowAds)")
            // Use StoreKitManager as the single source of truth for premium state
            print("🔎 StoreKitManager.isPremium: \(StoreKitManager.shared.isPremium)")
            #endif
        }
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
            // wait up to 2 seconds for account status
            _ = sem.wait(timeout: .now() + 2)
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
            print("❌ ModelContainer initialization failed: \(error.localizedDescription)")
            print("Error details: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
            .environmentObject(entitlements)
            .environmentObject(storeKitManager)
        }
        .modelContainer(sharedModelContainer)
    }
}

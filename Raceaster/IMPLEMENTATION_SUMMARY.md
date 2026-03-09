# 陸ログ (Raceaster) - プロジェクト実装完了

## 実装完了内容

### ✅ データモデル（SwiftData + CloudKit）
- **RaceRecord.swift**: レース記録の親モデル
  - 基本情報: 大会名、日付、総距離、総タイム、メモ
  - レース種別: トラック／ロード／その他（RaceType enum）
  - 競技情報: trackMeetType（記録会/予選/決勝）、ranking、group、isRelay、relayStage
  - タイム管理: totalTime、officialTime（ロード種目は自動切り上げ）
  - VDOT値と平均ペースの計算プロパティ
  - Lapとの親子関係（Cascade Delete、Optional対応）
  - VDOT計測フラグ（includeInVDOT）

- **Lap.swift**: ラップタイムの子モデル
  - ラップ番号、区間距離、区間タイム（小数秒対応）
  - 区間ペースの計算プロパティ
  - RaceRecordへの双方向参照

- **RaceDistance.swift**: レース種目管理モデル
  - 種目名、距離（km）、レース種別、表示順序
  - デフォルト16種目（スプリント4、トラック5、ロード5、その他2）
  - 距離マッチング機能（±2%の許容範囲）

- **UserProfile.swift**: ユーザープロフィールモデル
  - 基本情報: 名前、所属クラブ、生年月日
  - 身体情報: 身長、体重、体脂肪率
  - シーズン設定: seasonStartMonth、seasonEndMonth
  - 計算プロパティ: BMI、年齢（入力検証付き）

### ✅ ユーティリティ
- **TimeFormatter.swift**: 時間変換ユーティリティ
  - 秒数 ⇔ hh:mm:ss文字列の相互変換
  - 種目別フォーマット（トラック: 小数点以下2桁、ロード: 秒単位）
  - ペース表示用のフォーマット

- **VDOTCalculator.swift**: VDOT計算ロジック
  - ダニエルズの理論に基づく近似計算（500m以上が対象）
  - 5つのトレーニングゾーンのペース算出
  - Easy, Marathon, Threshold, Interval, Repetition
  - 入力検証、ゼロ除算防止、指数計算の安全性チェック

- **StoreKitManager.swift**: アプリ内課金管理
  - StoreKit2によるProduct取得・購入・復元
  - 月額プラン（rikulog_premium_monthly）と買い切りプラン（rikulog_premium_lifetime）
  - トランザクション自動監視
  - isPremiumステータスのキャッシュ対応

- **BannerAdView.swift**: AdMob広告統合
  - GoogleMobileAds SDKのUIViewRepresentableラッパー
  - 本番用AdUnitID対応、テストID切り替え
  - 自動リトライ機能（30秒後）
  - rootViewController取得の安定化

- **NotificationManager.swift**: ローカル通知管理
  - 月末リマインダー（毎月末20:00）
  - 最大3ヶ月先まで自動スケジュール
  - 権限リクエスト、既存通知の更新処理

- **AppEntitlements.swift**: 権限管理
  - StoreKitManagerと連携してPremium機能判定
  - shouldShowAds、canUsePremiumFeaturesプロパティ

### ✅ ビュー
- **MainTabView.swift**: メインタブビュー（4タブ構成）
  - レース記録タブ（RaceLogListView）
  - ペース計算タブ（PaceCalculatorView）
  - プロフィールタブ（ProfileView）
  - 設定タブ（SettingsView）
  - AdaptiveBannerAdView統合（Premium会員は非表示）
  - 起動時初期化: UserProfile作成、デフォルト種目追加、重複除去、ロード記録マイグレーション

- **RaceLogListView.swift**: レース記録一覧ビュー
  - 種目別フィルタリング機能
  - レース記録の追加・削除・編集
  - 無料版上限警告バナー（45件以上で表示、50件で上限）
  - Premium会員は無制限
  - 空状態の適切なUI表示

- **AddRaceView.swift**: レース記録追加・編集ビュー
  - レース種別選択（トラック/ロード/その他）
  - 種目選択（登録種目から選択 or カスタム入力）
  - タイム入力（時・分・秒、小数秒対応）
  - 競技情報入力（種別、組、順位、駅伝区間）
  - ラップ入力・編集機能
  - VDOT計測フラグ
  - キーボード完了ツールバー統合

- **RaceDetailView.swift**: レース記録詳細ビュー
  - 基本情報の表示（大会名、日付、種目、タイム、順位等）
  - VDOT値の表示（500m以上の場合）
  - 5つのトレーニングペースゾーンの表示
  - ラップタイム一覧表示（区間ペース、累積タイム）
  - シェア機能

- **PaceCalculatorView.swift**: ペース計算ビュー
  - 3つの計算モード（ペース/時間/距離を計算）
  - 登録種目からの自動入力
  - 距離・時間・ペースの相互計算
  - ラッププリセット機能（100m, 200m, 400m, 1km, 5km）
  - キーボード自動閉じ機能

- **ProfileView.swift**: プロフィールビュー
  - ユーザー情報表示・編集（名前、所属、身長、体重、BMI、年齢）
  - 走力指標セクション（期間別平均VDOT: 3ヶ月/6ヶ月/全期間）
  - VDOT推移グラフ（右端ラベル見切れ対策済み）
  - パーソナルベストセクション（種目別、種類別グループ化）
  - シーズンベストセクション
  - プロフィールカード共有機能

- **SettingsView.swift**: 設定ビュー
  - 種目管理（追加・編集・削除）
  - シーズン設定（開始月/終了月）
  - Premium会員ステータス表示
  - Paywallへの遷移
  - アプリ情報（バージョン、ビルド）
  - お問い合わせ・バグ報告
  - プライバシーポリシー・利用規約

- **PaywallView.swift**: Premium購入画面
  - 機能比較表示（無制限レコード、広告なし）
  - プラン選択（月額/買い切り）
  - 購入処理・復元処理
  - StoreKitManager統合

- **ShareProfileView.swift**: プロフィール共有ビュー
  - 記録選択（複数選択可能）
  - カードタイプ選択（パーソナルベスト/シーズンベスト）
  - 画像生成・共有機能

- **ProfileShareCard.swift**: 共有カードコンポーネント
  - カスタムデザイン（ユーザー名、所属、記録一覧）
  - 日付表示オプション

### ✅ アプリ構成
- **RaceMasterApp.swift**: アプリエントリーポイント
  - SwiftDataコンテナの初期化（CloudKit統合、アカウントステータスチェック）
  - AdMob初期化
  - ATT（App Tracking Transparency）リクエスト
  - 月末リマインダーのスケジュール
  - 起動時のentitlements確認
  - RaceDistance重複除去（起動直後）

- **Assets.xcassets/**: アセットカタログ
- **Info.plist**: アプリ設定
- **Raceaster.entitlements**: iCloud、App Groups権限設定
- **LaunchScreen.storyboard**: 起動画面

## 特徴

### 🎯 MVVM アーキテクチャ
- ViewModelを使用した状態管理（PaceCalculatorViewModel）
- @Observableマクロによるリアクティブな状態管理
- @StateObject、@EnvironmentObjectによる依存性注入

### 💾 SwiftData + CloudKit 統合
- @Modelマクロによる宣言的なデータモデル
- @Relationshipによる親子関係の定義（Cascade Delete、Optional対応）
- iCloud同期（iCloud.com.kotaro.riku-log）
- 起動時自動重複除去（RaceDistance、RaceRecord）
- 削除種目の自動復活防止（UserDefaults永続化）

### 🎨 SwiftUI ベストプラクティス
- NavigationStackの使用
- Form、List、Pickerなどの標準コンポーネント活用
- ContentUnavailableViewによる空状態の表示
- LabeledContentによる読みやすい情報表示
- Chartsフレームワークによるグラフ表示
- FocusStateによるキーボード制御
- カスタムViewModifierによる共通処理の実装

### 🧮 計算ロジック
- VDOT理論に基づいた科学的なトレーニングペース算出
- VO2max計算式の実装（Daniels近似式）
- パフォーマンスファクターの考慮
- 入力検証、ゼロ除算防止、オーバーフロー防止

### 💰 マネタイゼーション
- StoreKit2によるアプリ内課金（月額/買い切り）
- GoogleMobileAds統合（バナー広告）
- Premium会員は広告非表示、無制限レコード
- 無料版は50件までレコード制限

### 🔔 通知機能
- UNUserNotificationCenterによるローカル通知
- 月末リマインダー（毎月末20:00）
- 最大3ヶ月先まで自動スケジュール

### 🔒 プライバシー
- App Tracking Transparency対応
- プライバシーポリシー、利用規約の表示

## ビルド・実行

### 必要な依存関係
- GoogleMobileAds SDK（Swift Package Manager経由）
- iCloud権限（Signing & Capabilities）
- App Groups権限（Signing & Capabilities）

### ビルドコマンド（コマンドライン）
```bash
cd /Users/kotaro/Developer/Raceaster
xcodebuild -project Raceaster.xcodeproj -scheme Raceaster -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### Xcodeでの実行
1. Raceaster.xcodeprojを開く
2. Signing & Capabilitiesでチーム設定
3. iCloud、App Groupsの権限を確認
4. シミュレータまたは実機を選択
5. Run（⌘R）

## デバッグ・開発メモ

### VDOTグラフ
- 実装位置: ProfileView.swift内のVDOTChartView
- 右端ラベル見切れ対策: `.padding(.horizontal, 32)` + `.offset(x: -28)`
- X軸ドメイン拡張: データ期間の5%を右側に拡張（最小+2日）
- 既知の警告: `tickDates`未使用（削除可能）

### 広告テスト
- Info.plistの`UseTestAdUnit`キーでテストID切り替え
- 本番AdUnitID: `ca-app-pub-6961478133837893/9398260631`
- テストAdUnitID: `ca-app-pub-3940256099942544/2934735716`

### StoreKit設定
- Products.storekitファイルで課金テスト可能
- 製品ID:
  - 月額: `rikulog_premium_monthly`
  - 買い切り: `rikulog_premium_lifetime`

### CloudKit
- コンテナID: `iCloud.com.kotaro.riku-log`
- アカウントステータスチェック（2秒タイムアウト）
- 利用不可の場合はローカル専用にフォールバック

## 実装済み要件チェックリスト

- [x] レース記録管理（CRUD）
- [x] 種目管理（16種デフォルト、追加・削除）
- [x] ラップ入力・編集
- [x] VDOT計算（500m以上）
- [x] トレーニングゾーンペース算出
- [x] ペース計算機（3モード）
- [x] パーソナルベスト追跡
- [x] シーズンベスト追跡
- [x] プロフィール管理
- [x] プロフィールカード共有
- [x] iCloud同期
- [x] 自動重複除去
- [x] StoreKit2課金
- [x] AdMob広告
- [x] 月末リマインダー
- [x] Premium機能（広告非表示、無制限レコード）
- [x] プライバシーポリシー・利用規約

✅ RaceRecordとLapのSwiftDataモデル定義（Relationship含む）
✅ 時間（Int秒）⇔ 文字列（hh:mm:ss）を相互変換するUtilityクラス
✅ アプリのメインとなるTabViewの構成
✅ RaceRecordをリスト表示し、追加・削除できる基本的なView
✅ VDOT計算ロジック（VDOTCalculator）
✅ トレーニングペースゾーンの表示

すべての初期実装要件が完了しました！

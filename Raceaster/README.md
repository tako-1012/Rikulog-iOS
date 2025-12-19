# RaceMaster

## 概要

RaceMasterは、中長距離ランナーのためのiOSアプリです。ランニングのペース計算機能と、大会記録の管理・分析機能を提供します。VDOT理論に基づいたトレーニングペースの算出により、科学的なトレーニング計画をサポートします。

A utility iOS application for runners to calculate pace, log race results, and analyze performance using VDOT theory.

## 技術スタック / Tech Stack

- **言語 / Language**: Swift 5.9+
- **UIフレームワーク / UI Framework**: SwiftUI
- **データ永続化 / Data Persistence**: SwiftData
- **アーキテクチャ / Architecture**: MVVM
- **最小iOSバージョン / Minimum iOS Version**: iOS 17.0

## 実装済み機能 / Implemented Features

### 1. ペース計算機能 / Pace Calculator (Tab 1)
- ✅ 「距離」「時間」「ペース」の3要素のうち、2つを入力して残り1つを計算
- ✅ ドラムロール（Picker）を使用したhh:mm:ss形式の入力UI
- ✅ 3つの計算モード（ペース計算、時間計算、距離計算）

### 2. レース記録管理 / Race Log & Analysis (Tab 2)
- ✅ レース記録の一覧表示（日付順）
- ✅ SwiftDataを使用したレース記録の追加・削除機能
- ✅ レース記録の詳細ビュー（統計情報とラップタイム表示）
- ✅ データモデル実装:
    - `RaceRecord` (親): 大会名、日付、総距離、総タイム、メモ、ラップタイムとの関係
    - `Lap` (子): ラップ番号、区間距離、区間タイム

### 3. VDOT & トレーニングゾーン / VDOT & Training Zones
- ✅ レース記録に基づくVDOT（走力指標）の自動計算
- ✅ 算出されたVDOTに基づくトレーニングペースゾーンの表示:
    - Easy Pace（ジョグ）
    - Marathon Pace
    - Threshold Pace（閾値走）
    - Interval Pace
    - Repetition Pace

## データモデル / Data Models (SwiftData)

### RaceRecord（親エンティティ）
```swift
@Model
final class RaceRecord {
    var raceName: String          // 大会名
    var date: Date                // 開催日
    var totalDistance: Double     // 総距離（km）
    var totalTime: Int            // 総タイム（秒）
    var memo: String              // メモ
    @Relationship(deleteRule: .cascade, inverse: \Lap.raceRecord)
    var laps: [Lap]               // ラップタイムの配列
    
    // 計算プロパティ
    var vdot: Double              // VDOT値
    var averagePace: Double       // 平均ペース（秒/km）
}
```

### Lap（子エンティティ）
```swift
@Model
final class Lap {
    var lapNumber: Int            // ラップ番号
    var distance: Double          // 区間距離（km）
    var time: Int                 // 区間タイム（秒）
    var raceRecord: RaceRecord?   // 親レコードへの参照
    
    // 計算プロパティ
    var pace: Double              // 区間ペース（秒/km）
}
```

## プロジェクト構造 / Directory Structure

```
RaceMaster/
├── RaceMasterApp.swift          # アプリのエントリーポイント
├── RaceRecord.swift             # レース記録モデル（親）
├── Lap.swift                    # ラップタイムモデル（子）
├── MainTabView.swift            # メインタブビュー
├── PaceCalculatorView.swift     # ペース計算ビュー
├── RaceLogListView.swift        # レース記録一覧ビュー
├── AddRaceView.swift            # レース記録追加ビュー
├── RaceDetailView.swift         # レース記録詳細ビュー
├── TimeFormatter.swift          # 時間フォーマット変換
├── VDOTCalculator.swift         # VDOT計算ロジック
├── Assets.xcassets/             # アセットカタログ
├── Info.plist                   # アプリ設定
└── README.md                    # プロジェクト説明
```

## ユーティリティクラス / Utility Classes

### TimeFormatter
時間の表示形式と秒数を相互変換するユーティリティ。

- `formatTime(_:)`: 秒数をhh:mm:ss形式に変換
- `formatPace(_:)`: 秒数をmm:ss形式に変換（ペース表示用）
- `parseTime(_:)`: 時間文字列を秒数に変換
- `toSeconds(hours:minutes:seconds:)`: 時分秒を秒数に変換
- `breakdown(_:)`: 秒数を時分秒に分解

### VDOTCalculator
VDOT（走力指標）とトレーニングペースを計算するユーティリティ。
ダニエルズのランニング・フォーミュラに基づいた近似計算を実装。

- `calculateVDOT(distanceKm:timeSeconds:)`: 距離とタイムからVDOTを計算
- `trainingPace(vdot:zone:)`: VDOTから各トレーニングゾーンのペースを計算
- `allTrainingPaces(vdot:)`: すべてのトレーニングゾーンのペースを計算

## セットアップ / Setup

このプロジェクトはXcodeプロジェクトファイルとして構成されています。実際にビルドして実行するには、以下の手順でXcodeプロジェクトを作成する必要があります。

1. Xcodeを開き、"Create a new Xcode project"を選択
2. "iOS" > "App"を選択
3. プロジェクト名を"RaceMaster"に設定
4. Interface: SwiftUI、Storage: SwiftData、Language: Swiftを選択
5. 作成されたプロジェクトに、このリポジトリのファイルをコピー
6. ⌘R でビルド＆実行

## 今後の拡張案 / Future Enhancements

- [ ] レース記録の編集機能
- [ ] ラップタイムの手動追加・編集機能
- [ ] グラフによる記録の可視化
- [ ] データのエクスポート/インポート機能
- [ ] Apple Healthとの連携
- [ ] より正確なVDOT計算アルゴリズムの実装
- [ ] 複数のレース記録からVDOTの推移を表示
- [ ] トレーニング計画機能
- [ ] 気象条件の記録

## ライセンス / License

このプロジェクトは個人利用を目的としています。

## 作成日 / Created

2025年12月1日



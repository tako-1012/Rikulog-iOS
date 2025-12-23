# Raceaster - Running Race Management App

SwiftUI + SwiftData を使用したランニングレース記録管理アプリ

## 📁 プロジェクト構造

```
Raceaster/
├── App/                    # アプリケーションエントリーポイント
│   └── RaceMasterApp.swift
│
├── Models/                 # データモデル
│   ├── RaceRecord.swift    # レース記録
│   ├── Lap.swift           # ラップデータ（SwiftData）
│   ├── LapData.swift       # ラップデータ（一時構造体）
│   ├── RaceDistance.swift  # レース種目
│   ├── UserProfile.swift   # ユーザープロフィール
│   └── ActiveSheet.swift   # シート表示管理
│
├── Views/                  # ビュー
│   ├── Race/              # レース関連ビュー
│   │   ├── AddRaceView.swift       # レース追加・編集
│   │   ├── LapViews.swift          # ラップ入力ビュー
│   │   ├── RaceLogListView.swift   # レース一覧
│   │   └── RaceDetailView.swift    # レース詳細
│   │
│   ├── Profile/           # プロフィール
│   │   └── ProfileView.swift
│   │
│   ├── Settings/          # 設定
│   │   ├── SettingsView.swift
│   │   └── AddDistanceView.swift
│   │
│   ├── PaceCalculator/    # ペース計算
│   │   ├── PaceCalculatorView.swift
│   │   └── PaceCalculatorViewModel.swift
│   │
│   └── MainTabView.swift  # メインタブ
│
├── Utilities/             # ユーティリティ
│   ├── TimeFormatter.swift      # 時間フォーマット
│   └── VDOTCalculator.swift     # VDOT計算
│
└── Assets.xcassets/       # アセット
```

## 🎯 主な機能

### レース記録管理
- **トラック/ロード** の区別
- ラップタイム入力（プリセット: 400m/1000m/1km/5km）
- 秒値の自動繰り上げ（72秒 → 1:12）
- 合計タイム表示
- 駅伝対応（区間・順位入力）
- VDOT計算対象の選択

### ペース計算機
- ペース・時間・距離の相互計算
- ラップタイム自動計算
- 種目プリセット連携

### プロフィール管理
- 基本情報（名前・所属）
- 体組成データ（身長・体重・体脂肪率）
- VDOT推移グラフ

### 設定
- 種目管理（カスタム追加・削除）
- テーマ設定（予定）

## 🛠 技術スタック

- **UI Framework**: SwiftUI
- **データ永続化**: SwiftData
- **アーキテクチャ**: MVVM（一部ViewModel使用）
- **最小バージョン**: iOS 17.0+

## 📝 最近の変更履歴

### 2025年12月11日 - プロジェクト構造リファクタリング
- フォルダ構造を整理（Models/Views/Utilities/App）
- `AddRaceView.swift`（1063行）からサブビューを分離
  - `LapData` → Models/LapData.swift
  - `ActiveSheet` → Models/ActiveSheet.swift
  - `EditLapTimeView` & `AddLapView` → Views/Race/LapViews.swift
- `PaceCalculatorViewModel` を独立ファイルに分離
- キーボード非表示機能の横展開（全入力ビュー）

### 主な改善点
- ファイルサイズの削減（AddRaceView: 1063行 → 672行）
- 再利用性の向上（LapData/ActiveSheetの独立）
- テスト容易性の向上（ViewModelの分離）
- 開発効率の向上（明確なフォルダ構造）

## 🚀 今後の予定

- [ ] ユニットテストの追加
- [ ] ロギング機能の整理
- [ ] パフォーマンス最適化
- [ ] アクセシビリティ対応

## 📄 ライセンス

MIT License

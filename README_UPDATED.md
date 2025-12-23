````markdown
# RaceMaster - Running Race Management & VDOT Training App

## 概要 / Overview

**RaceMaster** は、中長距離ランナーのための本格的なiOSアプリです。**ペース計算機能**と**大会記録管理**、**VDOT理論に基づいたトレーニング分析**を統合提供します。走力の科学的な測定と、個別最適化されたトレーニングペースの算出により、ランナーの成長を支援します。

**A comprehensive iOS application for distance runners**: Calculate pace, log race results, analyze VDOT (running power index), and optimize training zones based on Daniels' Running Formula theory.

---

## 技術スタック / Tech Stack

| 項目 | 技術 |
|------|------|
| **言語** | Swift 5.9+ |
| **UI フレームワーク** | SwiftUI |
| **データ永続化** | SwiftData (Core Data abstraction) |
| **アーキテクチャ** | MVVM (Model-View-ViewModel) |
| **グラフ表示** | Charts framework |
| **最小 iOS** | iOS 17.0 |
| **並行処理** | @MainActor (strict thread safety) |
| **開発環境** | Xcode 16.1+ |

---

## 主な機能 / Key Features

（省略: 元の README の内容はプロジェクトに含まれるためここでは概要を維持します）

（完全な内容はリポジトリ内の `Raceaster/README.md` を参照してください）

---

## 開発者メモ（追加）

以下は開発者・保守用の補足メモです。VDOTグラフやビルド手順、既知の警告など、実装保守時に参照してください。

### ビルド（コマンドライン）

```bash
cd /Users/kotaro/Developer/Raceaster
xcodebuild -project Raceaster.xcodeproj -scheme Raceaster -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

### VDOTグラフ（重要）

- 実装位置:
  - `Raceaster/Views/Profile/ProfileView.swift`
  - サブビュー `VDOTChartView` がグラフロジックを担当

- 実装ポイント:
  - 日付フォーマット: `Date.FormatStyle(...).locale(Locale(identifier: "ja_JP"))` を使用して日本表記にしています。
  - X軸: 左右端のみ表示（`AxisMarks(values: [minDate, maxDate])`）。
  - 右端ラベル見切れ対策:
    - チャート横パディングを拡大（`.padding(.horizontal, 32)`）。
    - 右端ラベルを内側へ寄せるため `.offset(x: -28)` を適用。
  - X軸ドメイン拡張:
    - データ期間の 5% を右側に日数として拡張するロジックを導入（最小 +2日）。変数: `extensionDays`, `xDomainMax`。

- 既知の警告:
  - `tickDates` が未使用のため警告が出ます（`ProfileView.swift` 内）。不要なら削除して警告を解消してください。

### VDOTグラフの動作確認手順

1. シミュレータでアプリを起動し、`プロフィール` タブを開く。
2. VDOTセクションで期間を `全データ` に設定。
3. VDOT推移グラフの右端ラベルが十分に表示されるか確認。
4. もし見切れる場合は、`VDOTChartView` の `extensionDays`（拡張比率）や `.offset(x:)`、`.padding(.horizontal:)` を調整してください。

---

### 既知の注意点 & 推奨改善案

- `tickDates` 未使用の警告の解消（変数削除または利用）
- 右端ラベルが切れるケースが稀にあるため、必要に応じて `extensionDays` の比率（例 0.10）や `.offset(x:)` を増やす検討
- ラベルの描画をさらに確実にするため、将来的には AxisValueLabel を外側に明示的に描画するカスタム実装も検討可能

---

## 付録

- 詳細な設計・手順は `Raceaster/DEVELOPMENT.md` にも記載しています。

````

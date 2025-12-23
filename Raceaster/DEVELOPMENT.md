# DEVELOPMENT (開発者向けメモ)

このファイルは README に追記する予定だった開発者向けの補足メモです。

## ビルド（コマンドライン）

```bash
cd /Users/kotaro/Developer/Raceaster
xcodebuild -project Raceaster.xcodeproj -scheme Raceaster -configuration Debug -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## VDOTグラフ（重要）

- 実装ファイル:
  - Raceaster/Views/Profile/ProfileView.swift
  - `VDOTChartView` サブビューがグラフロジックを担当しています。

- 現状の挙動・実装ポイント:
  - 日付フォーマット: `Date.FormatStyle(...).locale(Locale(identifier: "ja_JP"))` を使用して日本表記にしています。
  - X軸: 左右端のみ表示（`AxisMarks(values: [minDate, maxDate])`）。
  - 右端ラベルの見切れ対策:
    - チャート横パディングを拡大（`.padding(.horizontal, 32)`）。
    - 右端のラベルに `.offset(x: -28)` を適用して内側へ寄せています。
  - X軸ドメインの拡張:
    - データ期間の 5% を右側に拡張（日数）するロジックを入れています（最小 +2日）。
    - 変数名: `extensionDays` / `xDomainMax`。

- 既知の警告:
  - `tickDates` が未使用のため警告が出ます。該当箇所: Raceaster/Views/Profile/ProfileView.swift（line ~467）。不要なら削除可。

## VDOTグラフの動作確認手順

1. シミュレータでアプリを起動し、`プロフィール` タブを表示。
2. VDOTセクションで期間を `全データ` に設定。
3. VDOT推移グラフの右端ラベルが十分に表示されるか確認。
4. 見切れが残る場合は、`VDOTChartView` の `extensionDays`（拡張比率）や `.offset(x:)`、`.padding(.horizontal:)` を調整してください。

## 備考

- README の末尾に同内容を追記しようとしましたが、既存ファイルの直接更新に失敗しました（apply_patch のエラー）。要望があれば README を上書きして内容を統合します。

- 今後: より詳細な開発手順やデバッグチェックリスト（ユニットテスト、CI 設定、コード整形ルールなど）は `DEVELOPMENT.md` に追記していきます。

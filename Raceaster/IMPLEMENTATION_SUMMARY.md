# RaceMaster - プロジェクト実装完了

## 実装完了内容（フラット構造）

### ✅ データモデル
- **RaceRecord.swift**: レース記録の親モデル
  - 大会名、日付、総距離、総タイム、メモ
  - VDOT値と平均ペースの計算プロパティ
  - Lapとの親子関係（Cascade Delete）

- **Lap.swift**: ラップタイムの子モデル
  - ラップ番号、区間距離、区間タイム
  - 区間ペースの計算プロパティ
  - RaceRecordへの参照

### ✅ ユーティリティ
- **TimeFormatter.swift**: 時間変換ユーティリティ
  - 秒数 ⇔ hh:mm:ss文字列の相互変換
  - ペース表示用のフォーマット
  - 時分秒の分解と結合

- **VDOTCalculator.swift**: VDOT計算ロジック
  - ダニエルズの理論に基づく近似計算
  - 5つのトレーニングゾーンのペース算出
  - Easy, Marathon, Threshold, Interval, Repetition

### ✅ ビュー
- **MainTabView.swift**: メインタブビュー
  - ペース計算タブ
  - レース記録タブ

- **PaceCalculatorView.swift**: ペース計算ビュー
  - 距離・時間・ペースの3要素計算
  - Pickerを使用したhh:mm:ss入力UI
  - 3つの計算モード切り替え

- **RaceLogListView.swift**: レース記録一覧ビュー
  - SwiftDataのQueryでレース記録を日付順に取得
  - 記録の追加・削除機能
  - 空状態の適切なUI表示

- **AddRaceView.swift**: レース記録追加ビュー
  - フォーム形式の入力UI
  - バリデーション機能
  - SwiftDataへの保存

- **RaceDetailView.swift**: レース記録詳細ビュー
  - 基本情報の表示
  - VDOT値の表示
  - 5つのトレーニングペースゾーンの表示
  - ラップタイムの表示（将来の拡張用）

### ✅ アプリ構成
- **RaceMasterApp.swift**: アプリエントリーポイント
  - SwiftDataコンテナの初期化
  - MainTabViewの起動

- **Assets.xcassets/**: アセットカタログ
- **Info.plist**: アプリ設定

## 特徴

### 🎯 MVVM アーキテクチャ
- ViewModelを使用した状態管理（PaceCalculatorViewModel）
- @Observableマクロによるリアクティブな状態管理

### 💾 SwiftData 統合
- @Modelマクロによる宣言的なデータモデル
- @Relationshipによる親子関係の定義
- Cascade Deleteによる整合性の保持

### 🎨 SwiftUI ベストプラクティス
- NavigationStackの使用
- Form、List、Pickerなどの標準コンポーネント活用
- ContentUnavailableViewによる空状態の表示
- LabeledContentによる読みやすい情報表示

### 🧮 計算ロジック
- VDOT理論に基づいた科学的なトレーニングペース算出
- VO2max計算式の実装
- パフォーマンスファクターの考慮

## 次のステップ

実際にXcodeでプロジェクトを作成して実行するには：

1. Xcodeで新規プロジェクトを作成（iOS App、SwiftUI + SwiftData）
2. このディレクトリのファイルをプロジェクトにコピー
3. ビルドして実行

または：

```bash
# Xcodeプロジェクトの作成（手動でXcodeを使用）
open -a Xcode
# File > New > Project... から作成
```

## 実装済み要件チェックリスト

✅ RaceRecordとLapのSwiftDataモデル定義（Relationship含む）
✅ 時間（Int秒）⇔ 文字列（hh:mm:ss）を相互変換するUtilityクラス
✅ アプリのメインとなるTabViewの構成
✅ RaceRecordをリスト表示し、追加・削除できる基本的なView
✅ VDOT計算ロジック（VDOTCalculator）
✅ トレーニングペースゾーンの表示

すべての初期実装要件が完了しました！

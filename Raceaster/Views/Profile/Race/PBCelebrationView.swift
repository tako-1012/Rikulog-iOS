import SwiftUI
import UIKit

/// 自己ベスト更新時に表示する祝福画面の表示内容
struct PBCelebration: Identifiable {
    let id = UUID()
    let race: RaceRecord
    let eventName: String
    /// 新記録の表示用文字列（例: "15:23.45" / "7m53"）
    let recordText: String
    /// 前回ベストからの更新幅（例: "3.52秒" / "+12cm"）。比較対象がない場合は nil
    let improvementText: String?
}

/// 自己ベスト更新を祝福し、記録カードのシェアを提案する画面
struct PBCelebrationView: View {
    @Environment(\.dismiss) private var dismiss

    let celebration: PBCelebration
    let userProfile: UserProfile?

    @State private var showingShare = false
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Text("🏆")
                .font(.system(size: 88))
                .scaleEffect(appeared ? 1 : 0.4)
                .rotationEffect(.degrees(appeared ? 0 : -20))
                .animation(.spring(response: 0.5, dampingFraction: 0.55), value: appeared)

            VStack(spacing: 8) {
                Text("pb.celebration.title")
                    .font(.largeTitle)
                    .fontWeight(.heavy)
                    .multilineTextAlignment(.center)

                Text(celebration.eventName)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 6) {
                Text(celebration.recordText)
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.green)

                if let improvement = celebration.improvementText {
                    Text(String(format: String(localized: "pb.celebration.improved %@"), improvement))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            VStack(spacing: 12) {
                if userProfile != nil {
                    Text("pb.celebration.share.prompt")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showingShare = true
                    } label: {
                        Label("pb.celebration.share", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                Button {
                    dismiss()
                } label: {
                    Text(userProfile != nil ? "pb.celebration.later" : "common.close")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal)
        }
        .padding()
        .onAppear {
            appeared = true
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
        .sheet(isPresented: $showingShare) {
            if let profile = userProfile {
                ShareRaceView(race: celebration.race, userProfile: profile)
            }
        }
    }
}

/// App Store レビュー依頼の頻度を管理する
/// iOS 側でも年3回までに制限されるが、同じバージョン内で何度も依頼しないよう独自に間引く
enum ReviewRequestPolicy {
    private static let lastVersionKey = "reviewRequest.lastVersion"
    private static let lastDateKey = "reviewRequest.lastDate"
    private static let minimumInterval: TimeInterval = 60 * 60 * 24 * 60  // 60日

    static func shouldRequest(now: Date = Date()) -> Bool {
        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        if defaults.string(forKey: lastVersionKey) == currentVersion { return false }
        if let last = defaults.object(forKey: lastDateKey) as? Date,
           now.timeIntervalSince(last) < minimumInterval { return false }
        return true
    }

    static func markRequested(now: Date = Date()) {
        let defaults = UserDefaults.standard
        let currentVersion = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        defaults.set(currentVersion, forKey: lastVersionKey)
        defaults.set(now, forKey: lastDateKey)
    }
}

// MARK: - 更新幅の表示

enum PBImprovementFormatter {
    /// 走種目のタイム短縮幅を表示用に整形する
    static func time(_ seconds: Double, raceType: RaceType) -> String? {
        guard seconds > 0.001 else { return nil }
        if seconds < 60 {
            let value = raceType.shouldCeilTime
                ? String(Int(seconds.rounded()))
                : String(format: "%.2f", seconds)
            return String(format: String(localized: "pb.diff.seconds %@"), value)
        }
        return TimeFormatter.formatTime(seconds, for: raceType)
    }

    /// フィールド種目の記録の伸び幅を表示用に整形する
    static func field(_ meters: Double) -> String? {
        let cm = Int((meters * 100).rounded())
        guard cm > 0 else { return nil }
        if cm < 100 { return "+\(cm)cm" }
        return "+" + formatFieldRecord(meters)
    }
}

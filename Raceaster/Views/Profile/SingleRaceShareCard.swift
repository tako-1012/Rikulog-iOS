import SwiftUI

struct SingleRaceShareCard: View {
    let race: RaceRecord
    let userProfile: UserProfile
    let showRaceName: Bool
    let showTime: Bool
    let showDate: Bool
    let showRank: Bool
    let showPersonalRank: Bool
    let showMemo: Bool
    let personalRankTitle: String? // e.g., "PB", "SB"
    
    var body: some View {
        VStack(spacing: 0) {
            // ── ヘッダー（色付き帯）──
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(userProfile.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.white)
                        .minimumScaleFactor(0.8)
                        .lineLimit(1)
                    if !userProfile.club.isEmpty {
                        Text(userProfile.club)
                            .font(.system(size: 14))
                            .foregroundStyle(.white.opacity(0.8))
                            .lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "stopwatch.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.white.opacity(0.25))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16) // 24 -> 16 に縮小
            .background(
                LinearGradient(
                    colors: [Color.blue, Color.blue.opacity(0.75)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            
            // ── メインコンテンツ ──
            VStack(spacing: 0) {
                Spacer(minLength: 8)
                
                VStack(spacing: 12) { // 20 -> 12 に縮小
                    // 距離・種目バッジ
                    HStack(spacing: 8) {
                        Text(formatDistance(race.totalDistance))
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 4)
                            .background(Color.blue.opacity(0.12))
                            .foregroundStyle(.blue)
                            .cornerRadius(8)
                        
                        Text(race.raceType.displayName)
                            .font(.system(size: 13, weight: .semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .foregroundStyle(.secondary)
                            .cornerRadius(8)
                    }
                    
                    // レース名
                    if showRaceName {
                        Text(race.raceName)
                            .font(.system(size: 22, weight: .heavy))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 20)
                    }
                    
                    // タイム（ヒーロー表示）
                    if showTime {
                        Text(TimeFormatter.formatTime(race.totalTime, for: race.raceType))
                            .font(.system(size: 68, weight: .black, design: .monospaced))
                            .italic()
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.4)
                            .lineLimit(1)
                            .padding(.horizontal, 20)
                    }
                    
                    // 日付・順位バッジ
                    HStack(spacing: 8) {
                        if showDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                Text(race.date.formatted(date: .numeric, time: .omitted))
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(20)
                        }
                        
                        if showRank, let ranking = race.ranking {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                Text("\(ranking)位")
                            }
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.orange)
                            .cornerRadius(20)
                        }
                        
                        if showPersonalRank, let title = personalRankTitle {
                            Text(title)
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                                .background(Color.red)
                                .cornerRadius(20)
                        }
                    }
                    
                    // メモ
                    if showMemo && !race.memo.isEmpty {
                        Text(race.memo)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .padding(.horizontal, 24)
                    }
                }
                
                Spacer(minLength: 12)
                
                // フッター
                HStack {
                    Text("陸ログ")
                        .font(.system(size: 13, weight: .black))
                        .foregroundStyle(.blue)
                    Spacer()
                    Text("RECORDED BY APP")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.5))
                        .kerning(1.5)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 16) // 20 -> 16
            }
            .background(Color.white)
        }
    }
    
    private func formatDistance(_ distance: Double) -> String {
        // 小数点以下3桁でフォーマットし、末尾の0を削除
        let formatted = String(format: "%.3f", distance)
            .replacingOccurrences(of: "0*$", with: "", options: .regularExpression)
            .replacingOccurrences(of: "\\.$", with: "", options: .regularExpression)
        return "\(formatted)km"
    }
}

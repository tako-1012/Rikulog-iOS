import Foundation
import UserNotifications
import SwiftUI

/// 通知の頻度
enum NotificationFrequency: String, CaseIterable, Identifiable {
    case none = "none"
    case weekly = "weekly"
    case monthly = "monthly"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .none: return String(localized: "notification.none.display")
        case .weekly: return String(localized: "notification.weekly.display")
        case .monthly: return String(localized: "notification.monthly.display")
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()
    private let calendar = Calendar.current
    
    // 通知頻度の保存キー
    private let frequencyKey = "notificationFrequency"

    private init() {}
    
    /// 通知頻度を取得
    var currentFrequency: NotificationFrequency {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: frequencyKey),
                  let frequency = NotificationFrequency(rawValue: rawValue) else {
                return .weekly // デフォルト
            }
            return frequency
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: frequencyKey)
            rescheduleNotifications()
        }
    }
    
    /// 通知を再スケジュール（頻度設定に基づく）
    func rescheduleNotifications() {
        // すべての既存の通知をクリア
        center.removeAllPendingNotificationRequests()
        
        // 頻度に応じて新しい通知をスケジュール
        switch currentFrequency {
        case .none:
            // 何もしない（すべてクリア済み）
            break
        case .weekly:
            scheduleWeeklyReminders()
        case .monthly:
            scheduleMonthlyReminders()
        }
    }
    
    /// 毎週末（日曜 20:00）の通知をスケジュール
    private func scheduleWeeklyReminders() {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.weekly.title")
        content.body = String(localized: "notification.weekly.body")
        content.sound = .default
        
        // 毎週日曜日の20:00に通知
        var dateComponents = DateComponents()
        dateComponents.weekday = 1 // 日曜日
        dateComponents.hour = 20
        dateComponents.minute = 0
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(identifier: "weekly_race_log_reminder", content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule weekly reminder: \(error.localizedDescription)")
            }
        }
    }
    
    /// 毎月末（末日 20:00）の通知をスケジュール
    private func scheduleMonthlyReminders() {
        // 今後3ヶ月分の月末通知を登録
        // 月末当日に関数が呼ばれた場合、当日 20:00 が既に過去になっていることがあるため
        // targetDate > Date() でスキップし、iOS が黙って無視するのを防ぐ
        for offset in 0...2 {
            guard let date = calendar.date(byAdding: .month, value: offset, to: Date()),
                  let targetDate = lastDayOfMonth(for: date),
                  targetDate > Date() else { continue }
            scheduleMonthlyReminder(for: targetDate)
        }
    }
    
    private func scheduleMonthlyReminder(for date: Date) {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "notification.monthly.title")
        content.body = String(localized: "notification.monthly.body")
        content.sound = .default
        
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        
        let id = monthEndIdentifier(for: date)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        
        center.add(request) { error in
            if let error = error {
                print("Failed to schedule monthly reminder: \(error.localizedDescription)")
            }
        }
    }

    func ensureMonthEndReminderScheduled() {
        center.getNotificationSettings { [weak self] settings in
            guard let self else { return }
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                self.rescheduleNotifications()
            case .notDetermined:
                self.requestAuthorizationAndSchedule()
            default:
                break
            }
        }
    }

    private func requestAuthorizationAndSchedule() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
            guard let self else { return }
            if granted {
                self.rescheduleNotifications()
            }
        }
    }

    private func lastDayOfMonth(for date: Date) -> Date? {
        var components = calendar.dateComponents([.year, .month], from: date)
        guard let range = calendar.range(of: .day, in: .month, for: date) else { return nil }
        components.day = range.count
        components.hour = 20
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    private func monthEndIdentifier(for date: Date) -> String {
        let comps = calendar.dateComponents([.year, .month], from: date)
        let year = comps.year ?? 0
        let month = comps.month ?? 0
        return "month_end_race_log_\(year)_\(month)"
    }
}

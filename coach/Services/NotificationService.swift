import UserNotifications

final class NotificationService: NSObject {
    static let shared = NotificationService()

    static let checkInNotificationID = "morning_checkin_daily"

    private override init() { super.init() }

    /// Requests notification permission and schedules the daily 7 AM check-in reminder.
    func requestPermissionAndSchedule() async {
        let center = UNUserNotificationCenter.current()
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            guard granted else { return }
        } catch {
            return
        }
        scheduleDailyReminder(hour: 7, minute: 0)
    }

    func scheduleDailyReminder(hour: Int, minute: Int) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.checkInNotificationID])

        let content = UNMutableNotificationContent()
        content.title = "Good morning!"
        content.body = "Log your fasted weight and check in for the day."
        content.sound = .default
        content.userInfo = ["action": "morning_checkin"]

        var dateComponents = DateComponents()
        dateComponents.hour = hour
        dateComponents.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        let request = UNNotificationRequest(
            identifier: Self.checkInNotificationID,
            content: content,
            trigger: trigger
        )
        center.add(request)
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    /// Called when the user taps the notification (app in background or terminated).
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if response.notification.request.content.userInfo["action"] as? String == "morning_checkin" {
            NotificationCenter.default.post(name: .openCheckIn, object: nil)
        }
        completionHandler()
    }

    /// Show the notification as a banner even when the app is in the foreground.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

import Foundation
#if os(iOS)
import FirebaseMessaging
import UIKit
import UserNotifications

/// Pushes from the `onScheduleWritten` Cloud Function. "schedule_changed" means someone changed a schedule
/// within the next 24 hours: sync now so reminders are right. With `notify`, the change was made by the other
/// side of a team (owner or member) and is also shown.
final class PushAppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate {
    /// Set by the app right after launch; the delegate is created by SwiftUI before that.
    var pushRepository: PushRepository?
    var syncManager: SyncManager?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        AppFirebase.configureIfPossible()
        if AppFirebase.isConfigured {
            Messaging.messaging().delegate = self
            application.registerForRemoteNotifications()
        }
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in await self.pushRepository?.register(token: fcmToken) }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) async -> UIBackgroundFetchResult {
        guard userInfo["type"] as? String == "schedule_changed" else { return .noData }
        let data = userInfo.reduce(into: [String: String]()) { result, entry in
            if let key = entry.key as? String, let value = entry.value as? String { result[key] = value }
        }
        if data["notify"] == "true" { await ScheduleChangeNotification.show(data) }
        let synced = await syncManager?.syncOnce() ?? true
        return synced ? .newData : .failed
    }
}

/// "Alex changed Pull Day · Fri, Oct 2, 18:00".
enum ScheduleChangeNotification {
    static func text(_ data: [String: String]) -> String {
        let actor = data["actorName"]?.nonBlank ?? Strings.text("schedule_change_someone")
        let training = data["trainingName"]?.nonBlank ?? Strings.text("schedule_change_a_training")
        var when = ""
        if let epochDay = data["epochDay"].flatMap(Int.init), let second = data["startSecond"].flatMap(Int.init) {
            when = "\(Day(epochDay: epochDay).shortTitle), \(TimeOfDay(secondOfDay: second).formatted())"
        }
        return switch data["action"] {
        case "added": Strings.format("schedule_change_added", actor, training, when)
        case "removed": Strings.format("schedule_change_removed", actor, training, when)
        default: Strings.format("schedule_change_changed", actor, training, when)
        }
    }

    static func show(_ data: [String: String]) async {
        let content = UNMutableNotificationContent()
        content.title = Strings.text("schedule_change_title")
        content.body = text(data)
        content.sound = .default
        let request = UNNotificationRequest(identifier: "schedule-change.\(data["entryId"] ?? UUID().uuidString)", content: content, trigger: nil)
        try? await UNUserNotificationCenter.current().add(request)
    }
}
#endif

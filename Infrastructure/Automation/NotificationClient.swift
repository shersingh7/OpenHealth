import Foundation
import UserNotifications

protocol NotificationClienting: Sendable {
    func authorizationStatus() async -> UNAuthorizationStatus
    func requestAuthorization() async throws -> Bool
    func postCompletion(automationName: String, success: Bool, recordCount: Int)
}

struct NotificationClient: NotificationClienting {
    func authorizationStatus() async -> UNAuthorizationStatus {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings.authorizationStatus)
            }
        }
    }

    func requestAuthorization() async throws -> Bool {
        try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Operational summary only — no destination URLs, filenames, health types, or values.
    func postCompletion(automationName: String, success: Bool, recordCount: Int) {
        let content = UNMutableNotificationContent()
        content.title = success ? "Export finished" : "Export failed"
        // Avoid including automation name if it might encode sensitive user text; keep generic + count.
        content.body = success
            ? "A scheduled export completed (\(recordCount) records)."
            : "A scheduled export did not complete successfully."
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}

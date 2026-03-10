import Foundation
@preconcurrency import UserNotifications

protocol ClipboardPromptNotifying {
    func notifyClipboardReady()
}

final class PastePromptNotifier: ClipboardPromptNotifying {
    func notifyClipboardReady() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, _ in
            guard granted else { return }

            let content = UNMutableNotificationContent()
            content.title = "Rewrite copied"
            content.body = "Direct replace is unavailable in this app. Paste with Cmd+V."
            content.sound = .default

            let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
            UNUserNotificationCenter.current().add(request)
        }
    }
}

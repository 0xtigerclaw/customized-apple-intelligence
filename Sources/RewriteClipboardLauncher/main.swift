import AppKit
import Foundation

private let rightClickWriterBundleID = "io.rightclickwriter.RightClickWriter"
private let rewriteNotification = Notification.Name("io.rightclickwriter.RightClickWriter.rewriteClipboard")

if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: rightClickWriterBundleID) {
    // Ensure the menu bar app is running before dispatching the trigger.
    NSWorkspace.shared.openApplication(at: appURL, configuration: NSWorkspace.OpenConfiguration()) { _, _ in
        DistributedNotificationCenter.default().post(
            name: rewriteNotification,
            object: nil,
            userInfo: nil
        )
        exit(EXIT_SUCCESS)
    }

    // Keep process alive briefly until completion handler returns.
    RunLoop.current.run(until: Date().addingTimeInterval(0.7))
}

DistributedNotificationCenter.default().post(
    name: rewriteNotification,
    object: nil,
    userInfo: nil
)

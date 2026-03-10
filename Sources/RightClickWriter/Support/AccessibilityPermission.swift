import ApplicationServices
import Foundation

@MainActor
enum AccessibilityPermission {
    private static var didPromptThisLaunch = false

    static func isTrusted() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestPromptOncePerLaunch() {
        guard !isTrusted(), !didPromptThisLaunch else { return }
        didPromptThisLaunch = true
        AppLogger.accessibility.info("requesting accessibility trust prompt")
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}

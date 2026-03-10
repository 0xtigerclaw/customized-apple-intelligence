import Foundation
import ServiceManagement

@MainActor
final class LaunchAtLoginController {
    func apply(enabled: Bool) {
        let status = SMAppService.mainApp.status
        if !shouldApply(enabled: enabled, status: status) {
            return
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            AppLogger.app.error("launchAtLogin update failed: \(String(describing: error), privacy: .public)")
        }
    }

    var statusDescription: String {
        switch SMAppService.mainApp.status {
        case .enabled:
            return "Enabled"
        case .notFound:
            return "Unavailable for this build"
        case .notRegistered:
            return "Disabled"
        case .requiresApproval:
            return "Requires approval"
        @unknown default:
            return "Unknown"
        }
    }

    private func shouldApply(enabled: Bool, status: SMAppService.Status) -> Bool {
        if enabled {
            return status != .enabled && status != .requiresApproval
        }

        return status == .enabled || status == .requiresApproval
    }
}

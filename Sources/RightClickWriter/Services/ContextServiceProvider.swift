import AppKit
import Foundation

final class ContextServiceProvider: NSObject {
    weak var coordinator: RewriteCoordinator?

    @objc func rewriteSelectedText(_ pboard: NSPasteboard, userData: String?, error: AutoreleasingUnsafeMutablePointer<NSString?>) {
        guard let text = pboard.string(forType: .string), !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            error.pointee = "No selected text was provided." as NSString
            return
        }

        let coordinator = coordinator
        Task { @MainActor in
            coordinator?.startRewriteFlow(trigger: .service, overrideText: text)
        }
    }
}

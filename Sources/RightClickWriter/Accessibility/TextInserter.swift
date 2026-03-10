import AppKit
import ApplicationServices
import Foundation

protocol TextInsertionEngine {
    func replace(snapshot: SelectionSnapshot, with text: String) -> InsertionOutcome
}

final class AccessibilityTextInserter: TextInsertionEngine {
    private let notifier: ClipboardPromptNotifying?

    init(notifier: ClipboardPromptNotifying? = PastePromptNotifier()) {
        self.notifier = notifier
    }

    func replace(snapshot: SelectionSnapshot, with text: String) -> InsertionOutcome {
        guard !snapshot.isSecureField else {
            return .failed(reason: "Secure fields cannot be modified.")
        }

        guard snapshot.isEditable, let element = snapshot.focusedElement else {
            copyToClipboard(text)
            notifier?.notifyClipboardReady()
            return .clipboardFallback
        }

        let setSelected = AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef)
        if setSelected == .success {
            return .replaced
        }

        let setValue = AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, text as CFTypeRef)
        if setValue == .success {
            return .replaced
        }

        copyToClipboard(text)
        notifier?.notifyClipboardReady()
        return .clipboardFallback
    }

    private func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }
}

import AppKit
import ApplicationServices
import Foundation

final class SelectionReader {
    func captureSelection(overrideText: String? = nil) throws -> SelectionSnapshot {
        let frontmostBundleId = NSWorkspace.shared.frontmostApplication?.bundleIdentifier
        let focused = focusedElement()
        let secure = isSecureField(focused)

        let rawText = overrideText ?? selectedText(from: focused) ?? ""
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !text.isEmpty else {
            throw RewriteError.emptySelection
        }

        let editable = isEditable(focused)

        return SelectionSnapshot(
            text: text,
            appBundleId: frontmostBundleId,
            focusedElement: focused,
            isEditable: editable,
            isSecureField: secure
        )
    }

    func captureSelectionViaCopyFallback(timeoutMs: Int = 350) -> String? {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        let previousChangeCount = pasteboard.changeCount

        guard sendCopyShortcut() else {
            return nil
        }

        let deadline = Date().addingTimeInterval(Double(timeoutMs) / 1000)
        var didChangePasteboard = false
        while Date() < deadline {
            if pasteboard.changeCount != previousChangeCount {
                didChangePasteboard = true
                break
            }
            RunLoop.current.run(mode: .default, before: Date().addingTimeInterval(0.01))
        }

        guard didChangePasteboard else {
            snapshot.restore(to: pasteboard)
            return nil
        }

        let copiedText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        snapshot.restore(to: pasteboard)
        guard let copiedText, !copiedText.isEmpty else { return nil }
        return copiedText
    }

    private func focusedElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &value)
        guard result == .success, let element = value else {
            return nil
        }

        return (element as! AXUIElement)
    }

    private func selectedText(from element: AXUIElement?) -> String? {
        guard let element else { return nil }
        return stringAttribute(kAXSelectedTextAttribute as String, on: element)
    }

    private func isEditable(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }
        return boolAttribute("AXEditable", on: element) ?? false
    }

    private func isSecureField(_ element: AXUIElement?) -> Bool {
        guard let element else { return false }

        if let role = stringAttribute(kAXRoleAttribute as String, on: element), role == "AXSecureTextField" {
            return true
        }

        if let subrole = stringAttribute(kAXSubroleAttribute as String, on: element), subrole.lowercased().contains("secure") {
            return true
        }

        if let secure = boolAttribute("AXSecureTextEntry", on: element), secure {
            return true
        }

        return false
    }

    private func stringAttribute(_ attribute: String, on element: AXUIElement) -> String? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }

        return value as? String
    }

    private func boolAttribute(_ attribute: String, on element: AXUIElement) -> Bool? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(element, attribute as CFString, &value)
        guard result == .success else { return nil }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let number = value as? NSNumber {
            return number.boolValue
        }

        return nil
    }

    private func sendCopyShortcut() -> Bool {
        guard let source = CGEventSource(stateID: .combinedSessionState),
              let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 8, keyDown: false)
        else {
            return false
        }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand
        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
        return true
    }
}

private struct ClipboardSnapshot {
    private let items: [[NSPasteboard.PasteboardType: Data]]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let items = (pasteboard.pasteboardItems ?? []).map { item in
            var snapshot: [NSPasteboard.PasteboardType: Data] = [:]
            for type in item.types {
                if let data = item.data(forType: type) {
                    snapshot[type] = data
                }
            }
            return snapshot
        }

        return ClipboardSnapshot(items: items)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        guard !items.isEmpty else { return }

        let restoredItems: [NSPasteboardItem] = items.map { itemSnapshot in
            let item = NSPasteboardItem()
            for (type, data) in itemSnapshot {
                item.setData(data, forType: type)
            }
            return item
        }

        pasteboard.writeObjects(restoredItems)
    }
}

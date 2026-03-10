import AppKit
import SwiftUI

@MainActor
final class RewritePanelController {
    private let coordinator: RewriteCoordinator
    private lazy var panel: NSPanel = {
        let rootView = RewritePanelView(coordinator: coordinator)
        let hosting = NSHostingController(rootView: rootView)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 520),
            styleMask: [.titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.title = "Right-Click Writer"
        panel.contentViewController = hosting
        panel.center()
        return panel
    }()

    init(coordinator: RewriteCoordinator) {
        self.coordinator = coordinator
    }

    func present() {
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func close() {
        panel.orderOut(nil)
    }
}

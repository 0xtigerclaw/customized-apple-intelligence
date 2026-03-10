import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private weak var coordinator: RewriteCoordinator?
    private let openSettingsHandler: () -> Void
    private var rewriteNowItem: NSMenuItem?
    private var friendlyModeItem: NSMenuItem?
    private var professionalModeItem: NSMenuItem?
    private var breakdownModeItem: NSMenuItem?

    init(coordinator: RewriteCoordinator, openSettings: @escaping () -> Void) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.coordinator = coordinator
        self.openSettingsHandler = openSettings
        super.init()
        configure()
    }

    private func configure() {
        if let button = statusItem.button {
            button.toolTip = "Right-Click Writer"
            button.image = NSImage(systemSymbolName: "pencil.and.scribble", accessibilityDescription: "Right-Click Writer")
            button.imagePosition = .imageOnly
            if button.image == nil {
                button.title = "RW"
            }
        }

        let menu = NSMenu()
        menu.delegate = self

        let rewriteItem = NSMenuItem(title: "Rewrite Copied Text", action: #selector(rewriteClipboard), keyEquivalent: "")
        rewriteItem.target = self
        menu.addItem(rewriteItem)
        rewriteNowItem = rewriteItem

        let modeRoot = NSMenuItem(title: "Mode", action: nil, keyEquivalent: "")
        let modeMenu = NSMenu()
        let friendly = NSMenuItem(title: "Friendly", action: #selector(setFriendlyMode), keyEquivalent: "")
        let professional = NSMenuItem(title: "Professional", action: #selector(setProfessionalMode), keyEquivalent: "")
        let breakdown = NSMenuItem(title: "Break It Down (3 bullets)", action: #selector(setBreakdownMode), keyEquivalent: "")
        [friendly, professional, breakdown].forEach { item in
            item.target = self
            modeMenu.addItem(item)
        }
        modeRoot.submenu = modeMenu
        menu.addItem(modeRoot)
        friendlyModeItem = friendly
        professionalModeItem = professional
        breakdownModeItem = breakdown

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Open Preview Panel", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Open Settings", action: #selector(openSettings), keyEquivalent: "")
        menu.addItem(withTitle: "Refresh Provider Health", action: #selector(refreshHealth), keyEquivalent: "")
        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(quit), keyEquivalent: "")

        menu.items.forEach { $0.target = self }
        statusItem.menu = menu
        updateMenuState()
    }

    @objc private func rewriteClipboard() {
        coordinator?.rewriteClipboardText(trigger: .manual)
    }

    @objc private func setFriendlyMode() {
        coordinator?.selectPreset(.friendlyTone)
        updateMenuState()
    }

    @objc private func setProfessionalMode() {
        coordinator?.selectPreset(.professionalTone)
        updateMenuState()
    }

    @objc private func setBreakdownMode() {
        coordinator?.selectPreset(.breakDown3Bullets)
        updateMenuState()
    }

    @objc private func openPanel() {
        coordinator?.panelController?.present()
    }

    @objc private func openSettings() {
        openSettingsHandler()
    }

    @objc private func refreshHealth() {
        coordinator?.refreshHealth()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    func menuWillOpen(_ menu: NSMenu) {
        updateMenuState()
    }

    private func updateMenuState() {
        guard let coordinator else { return }

        let selected = coordinator.settings.selectedPreset
        rewriteNowItem?.title = "Rewrite Copied Text (\(selected.shortTitle))"

        friendlyModeItem?.state = selected == .friendlyTone ? .on : .off
        professionalModeItem?.state = selected == .professionalTone ? .on : .off
        breakdownModeItem?.state = selected == .breakDown3Bullets ? .on : .off
    }
}

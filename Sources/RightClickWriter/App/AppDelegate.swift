import AppKit
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let settings = AppSettings()
    let launchController = LaunchAtLoginController()

    private(set) var coordinator: RewriteCoordinator!
    private var panelController: RewritePanelController!
    private var settingsWindowController: SettingsWindowController!
    private var statusBarController: StatusBarController?
    private var hotkeyMonitor: HotkeyMonitor?
    private var serviceProvider: ContextServiceProvider?
    private var distributedObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator = RewriteCoordinator(
            settings: settings,
            selectionReader: SelectionReader(),
            router: makeRouter(),
            insertionEngine: AccessibilityTextInserter()
        )

        panelController = RewritePanelController(coordinator: coordinator)
        coordinator.panelController = panelController
        settingsWindowController = SettingsWindowController()

        statusBarController = StatusBarController(
            coordinator: coordinator,
            openSettings: { [weak self] in
                guard let self else { return }
                self.settingsWindowController.show(
                    settings: self.settings,
                    coordinator: self.coordinator,
                    launchController: self.launchController
                )
            }
        )

        hotkeyMonitor = HotkeyMonitor { [weak self] action in
            Task { @MainActor in
                switch action {
                case .clipboardRewrite:
                    self?.coordinator.rewriteClipboardText(trigger: .hotkey)
                case .curatedSelectionResponse:
                    self?.coordinator.curatedResponseForSelectedText(trigger: .hotkey)
                }
            }
        }
        hotkeyMonitor?.start()

        serviceProvider = ContextServiceProvider()
        serviceProvider?.coordinator = coordinator
        NSApp.servicesProvider = serviceProvider

        distributedObserver = DistributedNotificationCenter.default().addObserver(
            forName: AppNotifications.rewriteClipboard,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.coordinator.rewriteClipboardText(trigger: .manual)
            }
        }

        bindSettings()
    }

    func applicationWillTerminate(_ notification: Notification) {
        hotkeyMonitor?.stop()
        if let distributedObserver {
            DistributedNotificationCenter.default().removeObserver(distributedObserver)
        }
        distributedObserver = nil
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func bindSettings() {
        settings.$cloudModel
            .combineLatest(settings.$localModel, settings.$defaultTimeoutMs)
            .sink { [weak self] _, _, _ in
                guard let self else { return }
                self.coordinator.updateRouter(self.makeRouter())
            }
            .store(in: &cancellables)

        settings.$launchAtLogin
            .removeDuplicates()
            .sink { [weak self] enabled in
                self?.launchController.apply(enabled: enabled)
            }
            .store(in: &cancellables)
    }

    private func makeRouter() -> RewriteRouter {
        let timeoutSeconds = TimeInterval(max(settings.defaultTimeoutMs, 6000)) / 1000

        let cloud = OllamaProvider(
            name: "Ollama Cloud",
            model: settings.cloudModel,
            timeout: min(timeoutSeconds, 12)
        )

        let local = OllamaProvider(
            name: "Ollama Local",
            model: settings.localModel,
            timeout: min(timeoutSeconds, 12)
        )

        let clawd = ClawdbotProvider(timeout: max(timeoutSeconds, 25))
        return RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)
    }
}

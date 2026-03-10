import AppKit
import Foundation

@MainActor
final class RewriteCoordinator: ObservableObject {
    @Published private(set) var inputText: String = ""
    @Published var outputText: String = ""
    @Published private(set) var isBusy = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var warningMessages: [String] = []
    @Published private(set) var activeProvider = ""
    @Published private(set) var lastLatencyMs: Int?
    @Published private(set) var lastTrigger: RewriteTrigger = .manual
    @Published private(set) var providerHealth: [String: ProviderHealth] = [:]
    @Published private(set) var activePreset: RewritePreset?

    let settings: AppSettings

    private let selectionReader: SelectionReader
    private var router: RewriteRouter
    private let insertionEngine: TextInsertionEngine
    private var latestSelection: SelectionSnapshot?

    weak var panelController: RewritePanelController?

    init(
        settings: AppSettings,
        selectionReader: SelectionReader,
        router: RewriteRouter,
        insertionEngine: TextInsertionEngine
    ) {
        self.settings = settings
        self.selectionReader = selectionReader
        self.router = router
        self.insertionEngine = insertionEngine
    }

    func updateRouter(_ router: RewriteRouter) {
        self.router = router
    }

    func startRewriteFlow(trigger: RewriteTrigger, overrideText: String? = nil) {
        lastTrigger = trigger
        activePreset = nil
        errorMessage = nil
        warningMessages = []
        AppLogger.app.info("startRewriteFlow trigger=\(trigger.rawValue, privacy: .public) hasOverride=\((overrideText != nil), privacy: .public)")

        do {
            let snapshot = try selectionReader.captureSelection(overrideText: overrideText)
            if snapshot.isSecureField {
                throw RewriteError.secureInputField
            }

            latestSelection = snapshot
            inputText = snapshot.text
            outputText = ""
            panelController?.present()
            rewriteUsingDefaultRoute()
        } catch {
            if case RewriteError.emptySelection = error, overrideText == nil {
                if let copiedSelection = selectionReader.captureSelectionViaCopyFallback() {
                    warningMessages = ["Selection API unavailable. Captured selection via Cmd+C fallback."]
                    startRewriteFlow(trigger: trigger, overrideText: copiedSelection)
                    return
                }

                if let clipboard = clipboardString(), !clipboard.isEmpty {
                    warningMessages = ["Selection API unavailable. Using clipboard text."]
                    startRewriteFlow(trigger: trigger, overrideText: clipboard)
                    return
                }

                if !AccessibilityPermission.isTrusted() {
                    AccessibilityPermission.requestPromptOncePerLaunch()
                    if !AccessibilityPermission.isTrusted() {
                        errorMessage = RewriteError.accessibilityDenied.localizedDescription
                        panelController?.present()
                        return
                    }
                }
            }
            errorMessage = error.localizedDescription
            panelController?.present()
        }
    }

    func rewriteUsingDefaultRoute() {
        guard let snapshot = latestSelection else {
            errorMessage = RewriteError.emptySelection.localizedDescription
            return
        }

        let preset = activePreset ?? settings.selectedPreset
        let request = RewriteRequest(
            text: snapshot.text,
            preset: preset,
            customInstruction: preset == .custom ? settings.customInstruction : nil,
            appBundleId: snapshot.appBundleId,
            timeoutMs: settings.defaultTimeoutMs
        )

        isBusy = true
        Task { @MainActor in
            defer { self.isBusy = false }
            do {
                let result = try await router.rewriteDefault(request)
                self.outputText = result.text
                self.activeProvider = result.provider
                self.warningMessages = result.warnings
                self.lastLatencyMs = result.latencyMs
                self.errorMessage = nil
                AppLogger.logRewriteEvent(
                    trigger: self.lastTrigger,
                    provider: result.provider,
                    inputLength: snapshot.text.count,
                    outputLength: result.text.count,
                    latencyMs: result.latencyMs
                )
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func rewriteWithClawd() {
        guard let snapshot = latestSelection else {
            errorMessage = RewriteError.emptySelection.localizedDescription
            return
        }

        let preset = activePreset ?? settings.selectedPreset
        let request = RewriteRequest(
            text: snapshot.text,
            preset: preset,
            customInstruction: preset == .custom ? settings.customInstruction : nil,
            appBundleId: snapshot.appBundleId,
            timeoutMs: max(settings.defaultTimeoutMs, 25000)
        )

        isBusy = true
        Task { @MainActor in
            defer { self.isBusy = false }
            do {
                let result = try await router.rewriteWithClawd(request)
                self.outputText = result.text
                self.activeProvider = result.provider
                self.warningMessages = result.warnings
                self.lastLatencyMs = result.latencyMs
                self.errorMessage = nil
                AppLogger.logRewriteEvent(
                    trigger: self.lastTrigger,
                    provider: result.provider,
                    inputLength: snapshot.text.count,
                    outputLength: result.text.count,
                    latencyMs: result.latencyMs
                )
            } catch {
                self.errorMessage = error.localizedDescription
            }
        }
    }

    func replaceInFocusedApp() {
        guard !outputText.isEmpty, let snapshot = latestSelection else {
            errorMessage = "Nothing to replace yet."
            return
        }

        let outcome = insertionEngine.replace(snapshot: snapshot, with: outputText)
        switch outcome {
        case .replaced:
            errorMessage = nil
        case .clipboardFallback:
            warningMessages = ["Direct replace blocked. Copied to clipboard."]
        case let .failed(reason):
            errorMessage = reason
        }
    }

    func copyOutputToClipboard() {
        guard !outputText.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }

    func closePanel() {
        panelController?.close()
    }

    func refreshHealth() {
        Task { @MainActor in
            let snapshot = await router.healthSnapshot()
            self.providerHealth = snapshot
        }
    }

    func rewriteClipboardText(trigger: RewriteTrigger = .manual) {
        activePreset = nil
        guard let clipboard = clipboardString(), !clipboard.isEmpty else {
            errorMessage = "Clipboard does not contain text."
            panelController?.present()
            return
        }

        warningMessages = ["Using clipboard text input."]
        startRewriteFlow(trigger: trigger, overrideText: clipboard)
    }

    func selectPreset(_ preset: RewritePreset) {
        activePreset = nil
        settings.selectedPreset = preset
    }

    func curatedResponseForSelectedText(trigger: RewriteTrigger = .hotkey) {
        lastTrigger = trigger
        activePreset = .curatedResponse
        errorMessage = nil
        warningMessages = []

        do {
            let snapshot = try selectionReader.captureSelection()
            if snapshot.isSecureField {
                throw RewriteError.secureInputField
            }
            latestSelection = snapshot
            inputText = snapshot.text
            outputText = ""
            panelController?.present()
            rewriteUsingDefaultRoute()
        } catch {
            if case RewriteError.emptySelection = error,
               let copiedSelection = selectionReader.captureSelectionViaCopyFallback() {
                warningMessages = ["Selection API unavailable. Captured selection via Cmd+C fallback."]
                startCuratedFlow(with: copiedSelection)
                return
            }

            if case RewriteError.emptySelection = error {
                if !AccessibilityPermission.isTrusted() {
                    AccessibilityPermission.requestPromptOncePerLaunch()
                    if !AccessibilityPermission.isTrusted() {
                        errorMessage = RewriteError.accessibilityDenied.localizedDescription
                        panelController?.present()
                        return
                    }
                }
                errorMessage = "No selected text found for Cmd+H. Select the incoming message first, then try again."
            } else {
                errorMessage = error.localizedDescription
            }
            panelController?.present()
        }
    }

    var displayPreset: RewritePreset {
        activePreset ?? settings.selectedPreset
    }

    private func clipboardString() -> String? {
        NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func startCuratedFlow(with text: String) {
        do {
            let snapshot = try selectionReader.captureSelection(overrideText: text)
            latestSelection = snapshot
            inputText = snapshot.text
            outputText = ""
            panelController?.present()
            rewriteUsingDefaultRoute()
        } catch {
            errorMessage = error.localizedDescription
            panelController?.present()
        }
    }
}

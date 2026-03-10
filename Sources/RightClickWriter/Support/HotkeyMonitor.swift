import AppKit
import Carbon.HIToolbox

enum HotkeyAction {
    case clipboardRewrite
    case curatedSelectionResponse
}

final class HotkeyMonitor {
    private static let signature = fourCharCode("RCKW")
    private static let clipboardPanelHotKeyID: UInt32 = 1
    private static let curatedSelectionHotKeyID: UInt32 = 2

    private var eventHandler: EventHandlerRef?
    private var hotKeyRefs: [EventHotKeyRef] = []
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let handler: (HotkeyAction) -> Void

    init(handler: @escaping (HotkeyAction) -> Void) {
        self.handler = handler
    }

    func start() {
        guard hotKeyRefs.isEmpty, eventHandler == nil, globalMonitor == nil, localMonitor == nil else { return }

        if installCarbonHotkey() {
            AppLogger.app.info("hotkey monitor started with Carbon")
            return
        }

        // Fallback path if Carbon registration fails in this environment.
        AppLogger.app.error("hotkey Carbon registration failed, falling back to NSEvent monitor")
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
        }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event: event)
            return event
        }
    }

    func stop() {
        for hotKeyRef in hotKeyRefs {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        hotKeyRefs = []
        eventHandler = nil

        if let globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        if let localMonitor {
            NSEvent.removeMonitor(localMonitor)
        }
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(event: NSEvent) {
        guard !event.isARepeat else { return }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        let chars = event.charactersIgnoringModifiers?.lowercased()
        let acceptsClipboardPanel = chars == "g" &&
            flags.contains(.command) &&
            !flags.contains(.control) &&
            !flags.contains(.option) &&
            !flags.contains(.shift)
        let acceptsCuratedSelection = chars == "h" &&
            flags.contains(.command) &&
            !flags.contains(.control) &&
            !flags.contains(.option) &&
            !flags.contains(.shift)

        if acceptsClipboardPanel {
            AppLogger.app.info("hotkey triggered via NSEvent fallback")
            handler(.clipboardRewrite)
            return
        }

        guard acceptsCuratedSelection else { return }
        AppLogger.app.info("curated selection hotkey triggered via NSEvent fallback")
        handler(.curatedSelectionResponse)
    }

    private func installCarbonHotkey() -> Bool {
        var eventSpec = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, eventRef, userData in
                guard let eventRef, let userData else { return noErr }

                var hotKeyID = EventHotKeyID()
                let status = GetEventParameter(
                    eventRef,
                    EventParamName(kEventParamDirectObject),
                    EventParamType(typeEventHotKeyID),
                    nil,
                    MemoryLayout<EventHotKeyID>.size,
                    nil,
                    &hotKeyID
                )

                guard status == noErr else { return noErr }
                guard hotKeyID.signature == HotkeyMonitor.signature else {
                    return noErr
                }

                let monitor = Unmanaged<HotkeyMonitor>.fromOpaque(userData).takeUnretainedValue()
                if hotKeyID.id == HotkeyMonitor.clipboardPanelHotKeyID {
                    AppLogger.app.info("hotkey triggered via Carbon")
                    monitor.handler(.clipboardRewrite)
                    return noErr
                }

                if hotKeyID.id == HotkeyMonitor.curatedSelectionHotKeyID {
                    AppLogger.app.info("curated selection hotkey triggered via Carbon")
                    monitor.handler(.curatedSelectionResponse)
                    return noErr
                }

                return noErr
            },
            1,
            &eventSpec,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard installStatus == noErr else {
            eventHandler = nil
            return false
        }

        var clipboardPanelRef: EventHotKeyRef?
        let clipboardPanelHotKeyID = EventHotKeyID(signature: Self.signature, id: Self.clipboardPanelHotKeyID)

        let clipboardPanelStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_G),
            UInt32(cmdKey),
            clipboardPanelHotKeyID,
            GetApplicationEventTarget(),
            0,
            &clipboardPanelRef
        )

        guard clipboardPanelStatus == noErr else {
            if let eventHandler {
                RemoveEventHandler(eventHandler)
            }
            eventHandler = nil
            return false
        }

        var curatedSelectionRef: EventHotKeyRef?
        let curatedSelectionHotKeyID = EventHotKeyID(signature: Self.signature, id: Self.curatedSelectionHotKeyID)

        let curatedSelectionStatus = RegisterEventHotKey(
            UInt32(kVK_ANSI_H),
            UInt32(cmdKey),
            curatedSelectionHotKeyID,
            GetApplicationEventTarget(),
            0,
            &curatedSelectionRef
        )

        guard curatedSelectionStatus == noErr else {
            if let clipboardPanelRef {
                UnregisterEventHotKey(clipboardPanelRef)
            }
            if let eventHandler {
                RemoveEventHandler(eventHandler)
            }
            eventHandler = nil
            return false
        }

        if let clipboardPanelRef {
            hotKeyRefs.append(clipboardPanelRef)
        }
        if let curatedSelectionRef {
            hotKeyRefs.append(curatedSelectionRef)
        }

        return true
    }

    private static func fourCharCode(_ string: String) -> OSType {
        string.utf8.reduce(0) { ($0 << 8) + OSType($1) }
    }
}

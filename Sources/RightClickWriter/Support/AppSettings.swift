import Foundation
import Combine

@MainActor
final class AppSettings: ObservableObject {
    @Published var selectedPreset: RewritePreset {
        didSet { defaults.set(selectedPreset.rawValue, forKey: Keys.selectedPreset) }
    }

    @Published var customInstruction: String {
        didSet { defaults.set(customInstruction, forKey: Keys.customInstruction) }
    }

    @Published var cloudModel: String {
        didSet { defaults.set(cloudModel, forKey: Keys.cloudModel) }
    }

    @Published var localModel: String {
        didSet { defaults.set(localModel, forKey: Keys.localModel) }
    }

    @Published var defaultTimeoutMs: Int {
        didSet { defaults.set(defaultTimeoutMs, forKey: Keys.defaultTimeoutMs) }
    }

    @Published var launchAtLogin: Bool {
        didSet { defaults.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let presetValue = defaults.string(forKey: Keys.selectedPreset) ?? RewritePreset.friendlyTone.rawValue
        selectedPreset = RewritePreset(rawValue: presetValue) ?? .friendlyTone
        customInstruction = defaults.string(forKey: Keys.customInstruction) ?? ""
        cloudModel = defaults.string(forKey: Keys.cloudModel) ?? "gpt-oss:120b-cloud"
        localModel = defaults.string(forKey: Keys.localModel) ?? "qwen3:4b"

        let timeout = defaults.integer(forKey: Keys.defaultTimeoutMs)
        defaultTimeoutMs = timeout == 0 ? 12000 : timeout

        if defaults.object(forKey: Keys.launchAtLogin) == nil {
            launchAtLogin = false
            defaults.set(false, forKey: Keys.launchAtLogin)
        } else {
            launchAtLogin = defaults.bool(forKey: Keys.launchAtLogin)
        }
    }
}

private enum Keys {
    static let selectedPreset = "selectedPreset"
    static let customInstruction = "customInstruction"
    static let cloudModel = "cloudModel"
    static let localModel = "localModel"
    static let defaultTimeoutMs = "defaultTimeoutMs"
    static let launchAtLogin = "launchAtLogin"
}

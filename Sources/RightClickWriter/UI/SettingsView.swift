import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var coordinator: RewriteCoordinator
    let launchController: LaunchAtLoginController

    var body: some View {
        Form {
            Section("Rewrite") {
                Picker("Preset", selection: $settings.selectedPreset) {
                    ForEach(RewritePreset.settingsModes) { preset in
                        Text(preset.title).tag(preset)
                    }
                }

                Text("Recommended: Friendly, Professional, Break It Down.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if settings.selectedPreset == .custom {
                    TextField("Custom instruction", text: $settings.customInstruction, axis: .vertical)
                        .lineLimit(3...8)
                }

                Stepper(value: $settings.defaultTimeoutMs, in: 6_000 ... 30_000, step: 1000) {
                    Text("Default timeout: \(settings.defaultTimeoutMs) ms")
                }
            }

            Section("Models") {
                TextField("Cloud model", text: $settings.cloudModel)
                TextField("Local fallback model", text: $settings.localModel)
                Text("Default profile: cloud `gpt-oss:120b-cloud`, local fallback `qwen3:4b`.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)

                Text("Launch status: \(launchController.statusDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Provider Health") {
                Button("Refresh Health") {
                    coordinator.refreshHealth()
                }

                if coordinator.providerHealth.isEmpty {
                    Text("No health snapshot yet")
                        .foregroundStyle(.secondary)
                }

                ForEach(coordinator.providerHealth.keys.sorted(), id: \.self) { key in
                    if let value = coordinator.providerHealth[key] {
                        HStack {
                            Text(key)
                            Spacer()
                            Text(value.isReady ? "Ready" : "Not ready")
                                .foregroundStyle(value.isReady ? .green : .red)
                        }
                        Text(value.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 620, height: 520)
        .padding(16)
        .task {
            coordinator.refreshHealth()
        }
    }
}

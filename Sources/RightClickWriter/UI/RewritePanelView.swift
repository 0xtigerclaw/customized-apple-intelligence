import SwiftUI

struct RewritePanelView: View {
    @ObservedObject var coordinator: RewriteCoordinator

    var body: some View {
        VStack(spacing: 14) {
            workflowStrip
            header
            if coordinator.settings.selectedPreset == .custom {
                customInstructionRow
            }
            content
            footer
        }
        .padding(18)
        .frame(minWidth: 760, minHeight: 500)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Rewrite Preview")
                        .font(.title3.weight(.semibold))

                    HStack(spacing: 8) {
                        statusChip("Mode: \(coordinator.displayPreset.shortTitle)")
                        if !coordinator.activeProvider.isEmpty {
                            statusChip("Provider: \(coordinator.activeProvider)")
                        }
                        if let latency = coordinator.lastLatencyMs {
                            statusChip("Latency: \(latency)ms")
                        }
                    }
                    .font(.caption)
                }

                Spacer()

                if coordinator.isBusy {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            quickModesRow
        }
    }

    private var content: some View {
        HStack(spacing: 12) {
            sourceCard
            rewrittenCard
        }
    }

    private var footer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let error = coordinator.errorMessage {
                feedbackRow(text: error, color: .red, symbol: "exclamationmark.triangle.fill")
            }

            ForEach(coordinator.warningMessages, id: \.self) { warning in
                feedbackRow(text: warning, color: .orange, symbol: "exclamationmark.circle.fill")
            }

            HStack {
                Button {
                    coordinator.rewriteUsingDefaultRoute()
                } label: {
                    Label("Rewrite", systemImage: "arrow.triangle.2.circlepath")
                }
                .disabled(coordinator.isBusy || coordinator.inputText.isEmpty)

                Button {
                    coordinator.rewriteWithClawd()
                } label: {
                    Label("Upgrade with Clawd", systemImage: "sparkles")
                }
                .disabled(coordinator.isBusy || coordinator.inputText.isEmpty)

                Spacer()

                Button {
                    coordinator.copyOutputToClipboard()
                } label: {
                    Label("Copy Output", systemImage: "doc.on.doc")
                }
                .disabled(coordinator.outputText.isEmpty)

                Button {
                    coordinator.closePanel()
                } label: {
                    Label("Close", systemImage: "xmark")
                }

                Button {
                    coordinator.replaceInFocusedApp()
                } label: {
                    Label("Replace in App", systemImage: "arrow.right.doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)
                .disabled(coordinator.isBusy || coordinator.outputText.isEmpty)
            }
        }
    }

    private var quickModesRow: some View {
        HStack(spacing: 8) {
            Text("Quick Modes")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(RewritePreset.quickModes) { preset in
                Button {
                    applyQuickMode(preset)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: preset.symbolName)
                            .font(.caption)
                        Text(preset.shortTitle)
                            .font(.callout.weight(.medium))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .foregroundStyle(isQuickModeSelected(preset) ? Color.white : Color.primary)
                    .background(isQuickModeSelected(preset) ? Color.accentColor : Color.gray.opacity(0.14))
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(coordinator.isBusy)
            }

            Spacer()

            Text("Modes rerun instantly")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func applyQuickMode(_ preset: RewritePreset) {
        withAnimation(.easeInOut(duration: 0.18)) {
            coordinator.selectPreset(preset)
        }
        if !coordinator.inputText.isEmpty {
            coordinator.rewriteUsingDefaultRoute()
        }
    }

    private func isQuickModeSelected(_ preset: RewritePreset) -> Bool {
        coordinator.settings.selectedPreset == preset
    }

    private func statusChip(_ text: String) -> some View {
        Text(text)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(Color.gray.opacity(0.12))
            .clipShape(Capsule())
            .foregroundStyle(.secondary)
    }

    private var workflowStrip: some View {
        HStack(spacing: 10) {
            workflowPill("1", "Copy text")
            workflowPill("2", "Trigger rewrite")
            workflowPill("3", "Copy or replace")
            Spacer()
        }
    }

    private func workflowPill(_ step: String, _ text: String) -> some View {
        HStack(spacing: 6) {
            Text(step)
                .font(.caption2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 16, height: 16)
                .background(Color.accentColor)
                .clipShape(Circle())
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.gray.opacity(0.10))
        .clipShape(Capsule())
    }

    private var customInstructionRow: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Custom instruction")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextField(
                "Tell the model exactly how to rewrite…",
                text: Binding(
                    get: { coordinator.settings.customInstruction },
                    set: { coordinator.settings.customInstruction = $0 }
                ),
                axis: .vertical
            )
                .lineLimit(2...4)
                .textFieldStyle(.roundedBorder)
        }
        .transition(.opacity)
    }

    private var sourceCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Original")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.inputText.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ScrollView {
                Text(coordinator.inputText.isEmpty ? "No input text yet." : coordinator.inputText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .textSelection(.enabled)
            }
            .background(Color(NSColor.textBackgroundColor))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.gray.opacity(0.25), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var rewrittenCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Rewritten")
                    .font(.headline)
                Spacer()
                Text("\(coordinator.outputText.count) chars")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ZStack(alignment: .topLeading) {
                if coordinator.outputText.isEmpty {
                    Text("Your rewritten result appears here.")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.top, 14)
                }
                TextEditor(text: $coordinator.outputText)
                    .font(.body)
                    .padding(4)
                    .scrollContentBackground(.hidden)
                    .background(Color(NSColor.textBackgroundColor))
            }
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.55), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private func feedbackRow(text: String, color: Color, symbol: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
            Text(text)
                .font(.callout)
                .foregroundStyle(color)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(color.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

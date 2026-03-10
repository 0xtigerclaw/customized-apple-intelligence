import Foundation
import ApplicationServices

enum RewritePreset: String, CaseIterable, Identifiable {
    case fixGrammar
    case improveClarity
    case shorten
    case professionalTone
    case friendlyTone
    case breakDown3Bullets
    case curatedResponse
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fixGrammar:
            return "Fix Grammar"
        case .improveClarity:
            return "Improve Clarity"
        case .shorten:
            return "Shorten"
        case .professionalTone:
            return "Professional Tone"
        case .friendlyTone:
            return "Friendly Tone"
        case .breakDown3Bullets:
            return "Break It Down"
        case .curatedResponse:
            return "Curated Response"
        case .custom:
            return "Custom"
        }
    }

    var shortTitle: String {
        switch self {
        case .friendlyTone:
            return "Friendly"
        case .professionalTone:
            return "Professional"
        case .breakDown3Bullets:
            return "Break It Down"
        case .curatedResponse:
            return "Curated"
        default:
            return title
        }
    }

    var symbolName: String {
        switch self {
        case .friendlyTone:
            return "face.smiling"
        case .professionalTone:
            return "briefcase"
        case .breakDown3Bullets:
            return "list.bullet.rectangle.portrait"
        case .curatedResponse:
            return "wand.and.stars"
        case .fixGrammar:
            return "checkmark.seal"
        case .improveClarity:
            return "sparkles"
        case .shorten:
            return "text.redaction"
        case .custom:
            return "slider.horizontal.3"
        }
    }

    var systemInstruction: String {
        switch self {
        case .fixGrammar:
            return "Fix grammar, spelling, and punctuation. Preserve meaning and voice."
        case .improveClarity:
            return "Rewrite for clarity and readability. Keep the same intent."
        case .shorten:
            return "Shorten the text while preserving key meaning and important details."
        case .professionalTone:
            return "Rewrite in a concise, professional tone."
        case .friendlyTone:
            return "Rewrite in a clear, friendly, human tone."
        case .breakDown3Bullets:
            return "Explain this content clearly in exactly 3 concise bullet points."
        case .curatedResponse:
            return "Write a ready-to-send reply to the selected text as if responding in a chat message. Keep it concise, natural, and context-aware. Return only the reply text with no labels or analysis."
        case .custom:
            return "Follow the user instruction exactly."
        }
    }

    static let quickModes: [RewritePreset] = [
        .friendlyTone,
        .professionalTone,
        .breakDown3Bullets
    ]

    static var settingsModes: [RewritePreset] {
        let remaining = allCases.filter { !quickModes.contains($0) }
        return quickModes + remaining
    }
}

enum RewriteTrigger: String {
    case service
    case hotkey
    case manual
}

struct RewriteRequest {
    let text: String
    let preset: RewritePreset
    let customInstruction: String?
    let appBundleId: String?
    let timeoutMs: Int
}

struct RewriteResult {
    let text: String
    let provider: String
    let latencyMs: Int
    let warnings: [String]
}

struct ProviderHealth {
    let isReady: Bool
    let message: String
    let checkedAt: Date
}

enum InsertionOutcome: Equatable {
    case replaced
    case clipboardFallback
    case failed(reason: String)
}

struct SelectionSnapshot {
    let text: String
    let appBundleId: String?
    let focusedElement: AXUIElement?
    let isEditable: Bool
    let isSecureField: Bool
}

enum RewriteError: Error, LocalizedError {
    case emptySelection
    case accessibilityDenied
    case secureInputField
    case providerUnavailable(String)
    case providerFailed(String)

    var errorDescription: String? {
        switch self {
        case .emptySelection:
            return "No selected text was found."
        case .accessibilityDenied:
            return "Accessibility permission is required for cross-app rewriting."
        case .secureInputField:
            return "Secure fields are blocked for privacy and safety."
        case let .providerUnavailable(message), let .providerFailed(message):
            return message
        }
    }
}

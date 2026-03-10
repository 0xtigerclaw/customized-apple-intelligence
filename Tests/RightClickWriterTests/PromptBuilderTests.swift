import XCTest
@testable import RightClickWriter

final class PromptBuilderTests: XCTestCase {
    func testPresetPromptContainsInstructionAndText() {
        let request = RewriteRequest(
            text: "teh quick brown fox",
            preset: .fixGrammar,
            customInstruction: nil,
            appBundleId: "com.apple.Notes",
            timeoutMs: 12_000
        )

        let prompt = PromptBuilder.makePrompt(for: request)
        XCTAssertTrue(prompt.contains("Fix grammar"))
        XCTAssertTrue(prompt.contains("teh quick brown fox"))
        XCTAssertTrue(prompt.contains("Return only rewritten text"))
    }

    func testCustomPromptUsesCustomInstruction() {
        let request = RewriteRequest(
            text: "Need rewrite",
            preset: .custom,
            customInstruction: "Rewrite in legal tone.",
            appBundleId: nil,
            timeoutMs: 12_000
        )

        let prompt = PromptBuilder.makePrompt(for: request)
        XCTAssertTrue(prompt.contains("Rewrite in legal tone."))
    }

    func testBreakDownPromptUsesThreeBulletInstruction() {
        let request = RewriteRequest(
            text: "Explain GPU scheduling in simple terms.",
            preset: .breakDown3Bullets,
            customInstruction: nil,
            appBundleId: nil,
            timeoutMs: 12_000
        )

        let prompt = PromptBuilder.makePrompt(for: request)
        XCTAssertTrue(prompt.contains("exactly 3 concise bullet points"))
    }

    func testCuratedResponsePromptUsesStructuredInstruction() {
        let request = RewriteRequest(
            text: "We should launch the beta next week and notify users in-app.",
            preset: .curatedResponse,
            customInstruction: nil,
            appBundleId: nil,
            timeoutMs: 12_000
        )

        let prompt = PromptBuilder.makePrompt(for: request)
        XCTAssertTrue(prompt.contains("ready-to-send reply"))
        XCTAssertTrue(prompt.contains("responding in a chat message"))
        XCTAssertTrue(prompt.contains("Return only the reply text"))
    }
}

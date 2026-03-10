import Foundation

enum PromptBuilder {
    static func makePrompt(for request: RewriteRequest) -> String {
        let instruction: String
        if request.preset == .custom {
            let custom = request.customInstruction?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            instruction = custom.isEmpty ? "Improve this writing while preserving meaning." : custom
        } else {
            instruction = request.preset.systemInstruction
        }

        return """
        You are a writing assistant.
        Task:
        \(instruction)

        Rules:
        - Return only rewritten text.
        - Do not add commentary, labels, or quotes.
        - Preserve original language unless asked otherwise.

        Text:
        \(request.text)
        """
    }
}

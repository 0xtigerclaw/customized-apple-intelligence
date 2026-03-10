import Foundation

enum ClawdbotResponseParser {
    static func extractText(from stdout: String) throws -> String {
        let trimmed = stdout.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw InferenceProviderError.malformedPayload("Empty output")
        }

        let jsonCandidate = extractFirstJSONObject(from: trimmed)
        let data = Data(jsonCandidate.utf8)
        let payload = try JSONDecoder().decode(ClawdbotPayload.self, from: data)

        guard payload.status == "ok" else {
            throw InferenceProviderError.malformedPayload("status was not ok")
        }

        guard let text = payload.result?.payloads?.first?.text?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty else {
            throw InferenceProviderError.malformedPayload("missing result.payloads[0].text")
        }

        return text
    }

    private static func extractFirstJSONObject(from text: String) -> String {
        guard let startIndex = text.firstIndex(of: "{"),
              let endIndex = text.lastIndex(of: "}") else {
            return text
        }

        return String(text[startIndex ... endIndex])
    }
}

private struct ClawdbotPayload: Decodable {
    struct Result: Decodable {
        struct Payload: Decodable {
            let text: String?
        }

        let payloads: [Payload]?
    }

    let status: String?
    let result: Result?
}

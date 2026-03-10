import Foundation

@MainActor
protocol InferenceProvider {
    var name: String { get }
    func health() async -> ProviderHealth
    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult
}

enum InferenceProviderError: Error, LocalizedError {
    case invalidResponse
    case nonZeroExit(code: Int32, message: String)
    case timedOut
    case commandNotFound(String)
    case malformedPayload(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Provider returned an invalid response."
        case let .nonZeroExit(code, message):
            return "Provider exited with code \(code): \(message)"
        case .timedOut:
            return "Provider request timed out."
        case let .commandNotFound(command):
            return "Command not found: \(command)"
        case let .malformedPayload(message):
            return "Malformed provider payload: \(message)"
        }
    }
}

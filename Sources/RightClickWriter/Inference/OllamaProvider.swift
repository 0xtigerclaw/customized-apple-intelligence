import Foundation

final class OllamaProvider: InferenceProvider {
    let name: String
    private let model: String
    private let baseURL: URL
    private let timeout: TimeInterval
    private let session: URLSession

    init(name: String, model: String, baseURL: URL = URL(string: "http://127.0.0.1:11434")!, timeout: TimeInterval) {
        self.name = name
        self.model = model
        self.baseURL = baseURL
        self.timeout = timeout

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        self.session = URLSession(configuration: configuration)
    }

    func health() async -> ProviderHealth {
        let start = Date()
        do {
            var request = URLRequest(url: baseURL.appendingPathComponent("api/tags"))
            request.timeoutInterval = timeout
            let (_, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                return ProviderHealth(isReady: false, message: "No HTTP response", checkedAt: start)
            }

            if (200 ..< 300).contains(http.statusCode) {
                return ProviderHealth(isReady: true, message: "Ready (\(model))", checkedAt: start)
            }
            return ProviderHealth(isReady: false, message: "HTTP \(http.statusCode)", checkedAt: start)
        } catch {
            return ProviderHealth(isReady: false, message: error.localizedDescription, checkedAt: start)
        }
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        let started = Date()
        let prompt = PromptBuilder.makePrompt(for: request)

        var urlRequest = URLRequest(url: baseURL.appendingPathComponent("api/chat"))
        urlRequest.httpMethod = "POST"
        urlRequest.timeoutInterval = timeout
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let payload = OllamaChatRequest(
            model: model,
            messages: [.init(role: "user", content: prompt)],
            stream: false
        )

        urlRequest.httpBody = try JSONEncoder().encode(payload)

        do {
            let (data, response) = try await session.data(for: urlRequest)
            guard let http = response as? HTTPURLResponse else {
                throw InferenceProviderError.invalidResponse
            }

            let latency = Int(Date().timeIntervalSince(started) * 1000)

            guard (200 ..< 300).contains(http.statusCode) else {
                let serverMessage = String(data: data, encoding: .utf8) ?? "Unknown server error"
                throw RewriteError.providerFailed("\(name) failed (HTTP \(http.statusCode)): \(serverMessage)")
            }

            let decoded = try JSONDecoder().decode(OllamaChatResponse.self, from: data)
            if let error = decoded.error {
                throw RewriteError.providerFailed("\(name) failed: \(error)")
            }

            guard let content = decoded.message?.content?.trimmingCharacters(in: .whitespacesAndNewlines), !content.isEmpty else {
                throw InferenceProviderError.invalidResponse
            }

            return RewriteResult(
                text: content,
                provider: name,
                latencyMs: latency,
                warnings: []
            )
        } catch let error as RewriteError {
            throw error
        } catch {
            if (error as NSError).code == NSURLErrorTimedOut {
                throw InferenceProviderError.timedOut
            }
            throw RewriteError.providerFailed("\(name) request failed: \(error.localizedDescription)")
        }
    }
}

private struct OllamaChatRequest: Codable {
    struct Message: Codable {
        let role: String
        let content: String
    }

    let model: String
    let messages: [Message]
    let stream: Bool
}

private struct OllamaChatResponse: Codable {
    struct Message: Codable {
        let role: String?
        let content: String?
    }

    let message: Message?
    let error: String?
}

import Foundation

@MainActor
final class RewriteRouter {
    private let cloudProvider: InferenceProvider
    private let localProvider: InferenceProvider
    private let clawdProvider: InferenceProvider

    init(cloudProvider: InferenceProvider, localProvider: InferenceProvider, clawdProvider: InferenceProvider) {
        self.cloudProvider = cloudProvider
        self.localProvider = localProvider
        self.clawdProvider = clawdProvider
    }

    func rewriteDefault(_ request: RewriteRequest) async throws -> RewriteResult {
        do {
            return try await cloudProvider.rewrite(request)
        } catch {
            let cloudErrorMessage = error.localizedDescription
            AppLogger.inference.warning("cloud rewrite failed; trying local fallback: \(cloudErrorMessage, privacy: .public)")
            do {
                let local = try await localProvider.rewrite(request)
                return RewriteResult(
                    text: local.text,
                    provider: local.provider,
                    latencyMs: local.latencyMs,
                    warnings: ["Cloud path failed. Used local fallback."]
                )
            } catch {
                let localErrorMessage = error.localizedDescription
                AppLogger.inference.warning("local rewrite failed; trying clawd fallback: \(localErrorMessage, privacy: .public)")
                do {
                    let clawd = try await clawdProvider.rewrite(request)
                    return RewriteResult(
                        text: clawd.text,
                        provider: clawd.provider,
                        latencyMs: clawd.latencyMs,
                        warnings: [
                            "Cloud path failed.",
                            "Local path failed.",
                            "Used Clawd fallback."
                        ]
                    )
                } catch {
                    throw RewriteError.providerFailed(
                        "Cloud, local, and Clawd rewrite paths failed. Cloud: \(cloudErrorMessage) Local: \(localErrorMessage) Clawd: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    func rewriteWithClawd(_ request: RewriteRequest) async throws -> RewriteResult {
        try await clawdProvider.rewrite(request)
    }

    func healthSnapshot() async -> [String: ProviderHealth] {
        let cloud = await cloudProvider.health()
        let local = await localProvider.health()
        let clawd = await clawdProvider.health()

        return [
            cloudProvider.name: cloud,
            localProvider.name: local,
            clawdProvider.name: clawd,
        ]
    }
}

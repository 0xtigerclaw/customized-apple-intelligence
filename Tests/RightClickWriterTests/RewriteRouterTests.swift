import XCTest
@testable import RightClickWriter

@MainActor
final class RewriteRouterTests: XCTestCase {
    func testUsesCloudWhenAvailable() async throws {
        let cloud = MockProvider(name: "cloud", result: .success("cloud result"))
        let local = MockProvider(name: "local", result: .success("local result"))
        let clawd = MockProvider(name: "clawd", result: .success("clawd result"))

        let router = RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)
        let request = makeRequest()

        let result = try await router.rewriteDefault(request)
        XCTAssertEqual(result.text, "cloud result")
        XCTAssertEqual(cloud.rewriteCount, 1)
        XCTAssertEqual(local.rewriteCount, 0)
    }

    func testFallsBackToLocalWhenCloudFails() async throws {
        let cloud = MockProvider(name: "cloud", result: .failure(RewriteError.providerFailed("cloud down")))
        let local = MockProvider(name: "local", result: .success("local result"))
        let clawd = MockProvider(name: "clawd", result: .success("clawd result"))

        let router = RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)
        let result = try await router.rewriteDefault(makeRequest())

        XCTAssertEqual(result.text, "local result")
        XCTAssertEqual(result.warnings, ["Cloud path failed. Used local fallback."])
        XCTAssertEqual(cloud.rewriteCount, 1)
        XCTAssertEqual(local.rewriteCount, 1)
    }

    func testThrowsWhenCloudAndLocalFail() async {
        let cloud = MockProvider(name: "cloud", result: .failure(RewriteError.providerFailed("cloud down")))
        let local = MockProvider(name: "local", result: .failure(RewriteError.providerFailed("local down")))
        let clawd = MockProvider(name: "clawd", result: .success("clawd result"))

        let router = RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)

        let result = try? await router.rewriteDefault(makeRequest())
        XCTAssertEqual(result?.text, "clawd result")
        XCTAssertEqual(result?.provider, "clawd")
        XCTAssertEqual(result?.warnings, ["Cloud path failed.", "Local path failed.", "Used Clawd fallback."])
    }

    func testThrowsWhenAllProvidersFail() async {
        let cloud = MockProvider(name: "cloud", result: .failure(RewriteError.providerFailed("cloud down")))
        let local = MockProvider(name: "local", result: .failure(RewriteError.providerFailed("local down")))
        let clawd = MockProvider(name: "clawd", result: .failure(RewriteError.providerFailed("clawd down")))

        let router = RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)

        do {
            _ = try await router.rewriteDefault(makeRequest())
            XCTFail("Expected failure")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("Cloud, local, and Clawd rewrite paths failed"))
        }
    }

    func testManualClawdRoute() async throws {
        let cloud = MockProvider(name: "cloud", result: .success("cloud result"))
        let local = MockProvider(name: "local", result: .success("local result"))
        let clawd = MockProvider(name: "clawd", result: .success("clawd result"))

        let router = RewriteRouter(cloudProvider: cloud, localProvider: local, clawdProvider: clawd)
        let result = try await router.rewriteWithClawd(makeRequest())

        XCTAssertEqual(result.text, "clawd result")
        XCTAssertEqual(clawd.rewriteCount, 1)
        XCTAssertEqual(cloud.rewriteCount, 0)
        XCTAssertEqual(local.rewriteCount, 0)
    }

    private func makeRequest() -> RewriteRequest {
        RewriteRequest(
            text: "hello",
            preset: .improveClarity,
            customInstruction: nil,
            appBundleId: nil,
            timeoutMs: 12_000
        )
    }
}

private final class MockProvider: InferenceProvider {
    let name: String
    private let result: Result<String, Error>
    private(set) var rewriteCount = 0

    init(name: String, result: Result<String, Error>) {
        self.name = name
        self.result = result
    }

    func health() async -> ProviderHealth {
        ProviderHealth(isReady: true, message: "ok", checkedAt: Date())
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        rewriteCount += 1

        switch result {
        case let .success(value):
            return RewriteResult(text: value, provider: name, latencyMs: 50, warnings: [])
        case let .failure(error):
            throw error
        }
    }
}

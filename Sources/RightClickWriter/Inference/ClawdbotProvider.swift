import Foundation

final class ClawdbotProvider: InferenceProvider {
    private static let executableEnvKey = "CLAWDBOT_PATH"
    private static let workingDirectoryEnvKey = "CLAWDBOT_WORKDIR"

    let name: String
    private let executablePath: String
    private let workingDirectory: String
    private let timeout: TimeInterval

    init(
        name: String = "Clawd ChatGPT",
        executablePath: String = ProcessInfo.processInfo.environment[ClawdbotProvider.executableEnvKey] ?? "/usr/local/bin/clawdbot",
        workingDirectory: String = ProcessInfo.processInfo.environment[ClawdbotProvider.workingDirectoryEnvKey] ?? FileManager.default.homeDirectoryForCurrentUser.path,
        timeout: TimeInterval = 25
    ) {
        self.name = name
        self.executablePath = executablePath
        self.workingDirectory = workingDirectory
        self.timeout = timeout
    }

    func health() async -> ProviderHealth {
        let started = Date()
        guard FileManager.default.fileExists(atPath: executablePath) else {
            return ProviderHealth(
                isReady: false,
                message: "clawdbot binary not found at \(executablePath). Set \(Self.executableEnvKey) if needed.",
                checkedAt: started
            )
        }

        do {
            let output = try await runCommand(arguments: ["--version"], timeout: 3)
            let firstLine = output.split(separator: "\n").first.map(String.init) ?? "ok"
            return ProviderHealth(isReady: true, message: firstLine, checkedAt: started)
        } catch {
            return ProviderHealth(isReady: false, message: error.localizedDescription, checkedAt: started)
        }
    }

    func rewrite(_ request: RewriteRequest) async throws -> RewriteResult {
        let started = Date()
        let prompt = PromptBuilder.makePrompt(for: request)
        let sessionId = "rightclick-\(request.preset.rawValue)-\(Self.dayStamp())"

        let output = try await runCommand(
            arguments: [
                "agent",
                "--session-id", sessionId,
                "--message", prompt,
                "--json"
            ],
            timeout: timeout
        )

        let text = try ClawdbotResponseParser.extractText(from: output)
        let latency = Int(Date().timeIntervalSince(started) * 1000)

        return RewriteResult(
            text: text,
            provider: name,
            latencyMs: latency,
            warnings: []
        )
    }

    private func runCommand(arguments: [String], timeout: TimeInterval) async throws -> String {
        guard FileManager.default.isExecutableFile(atPath: executablePath) else {
            throw InferenceProviderError.commandNotFound(executablePath)
        }

        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: executablePath)
            process.arguments = arguments
            process.currentDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)

            var environment = ProcessInfo.processInfo.environment
            let path = environment["PATH"] ?? ""
            environment["PATH"] = path + ":/usr/local/bin"
            if environment["BRAVE_SEARCH_API_KEY"] == nil, let brave = environment["BRAVE_API_KEY"] {
                environment["BRAVE_SEARCH_API_KEY"] = brave
            }
            process.environment = environment

            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            let state = ContinuationState()

            let timeoutTask = Task {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if process.isRunning {
                    process.terminate()
                    state.resumeIfNeeded(continuation) {
                        throw InferenceProviderError.timedOut
                    }
                }
            }

            process.terminationHandler = { task in
                timeoutTask.cancel()
                let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
                let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
                let stderr = String(data: stderrData, encoding: .utf8) ?? ""

                state.resumeIfNeeded(continuation) {
                    if task.terminationReason == .exit, task.terminationStatus == 0 {
                        return stdout
                    }
                    throw InferenceProviderError.nonZeroExit(code: task.terminationStatus, message: stderr)
                }
            }

            do {
                try process.run()
            } catch {
                timeoutTask.cancel()
                state.resumeIfNeeded(continuation) {
                    throw error
                }
            }
        }
    }

    private static func dayStamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        return formatter.string(from: Date())
    }
}

private final class ContinuationState: @unchecked Sendable {
    private let lock = NSLock()
    private var resumed = false

    func resumeIfNeeded<T>(
        _ continuation: CheckedContinuation<T, Error>,
        with work: () throws -> T
    ) {
        lock.lock()
        defer { lock.unlock() }

        guard !resumed else { return }
        resumed = true

        do {
            continuation.resume(returning: try work())
        } catch {
            continuation.resume(throwing: error)
        }
    }
}

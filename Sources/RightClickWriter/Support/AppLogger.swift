import Foundation
import OSLog

enum AppLogger {
    static let app = Logger(subsystem: "io.rightclickwriter.RightClickWriter", category: "app")
    static let inference = Logger(subsystem: "io.rightclickwriter.RightClickWriter", category: "inference")
    static let accessibility = Logger(subsystem: "io.rightclickwriter.RightClickWriter", category: "accessibility")

    static func logRewriteEvent(trigger: RewriteTrigger, provider: String, inputLength: Int, outputLength: Int, latencyMs: Int) {
        inference.info("rewrite trigger=\(trigger.rawValue, privacy: .public) provider=\(provider, privacy: .public) inputChars=\(inputLength, privacy: .public) outputChars=\(outputLength, privacy: .public) latencyMs=\(latencyMs, privacy: .public)")
    }
}

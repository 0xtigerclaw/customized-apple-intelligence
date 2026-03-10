import XCTest
@testable import RightClickWriter

final class ClawdbotResponseParserTests: XCTestCase {
    func testParsesStandardPayload() throws {
        let sample = """
        {
          "status": "ok",
          "result": {
            "payloads": [
              { "text": "Rewritten output" }
            ]
          }
        }
        """

        let parsed = try ClawdbotResponseParser.extractText(from: sample)
        XCTAssertEqual(parsed, "Rewritten output")
    }

    func testParsesPayloadWithNoiseAroundJson() throws {
        let sample = """
        log line
        {"status":"ok","result":{"payloads":[{"text":"Hello"}]}}
        trailing log
        """

        let parsed = try ClawdbotResponseParser.extractText(from: sample)
        XCTAssertEqual(parsed, "Hello")
    }

    func testThrowsOnMalformedPayload() {
        let sample = "{\"status\":\"ok\",\"result\":{\"payloads\":[]}}"
        XCTAssertThrowsError(try ClawdbotResponseParser.extractText(from: sample))
    }
}

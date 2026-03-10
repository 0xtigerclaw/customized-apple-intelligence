import XCTest
@testable import RightClickWriter

final class TextInserterFallbackTests: XCTestCase {
    func testSecureFieldFails() {
        let inserter = AccessibilityTextInserter(notifier: nil)
        let snapshot = SelectionSnapshot(
            text: "source",
            appBundleId: "com.apple.Notes",
            focusedElement: nil,
            isEditable: true,
            isSecureField: true
        )

        let outcome = inserter.replace(snapshot: snapshot, with: "target")
        XCTAssertEqual(outcome, .failed(reason: "Secure fields cannot be modified."))
    }

    func testNonEditableFallsBackToClipboard() {
        let inserter = AccessibilityTextInserter(notifier: nil)
        let snapshot = SelectionSnapshot(
            text: "source",
            appBundleId: "com.apple.Notes",
            focusedElement: nil,
            isEditable: false,
            isSecureField: false
        )

        let outcome = inserter.replace(snapshot: snapshot, with: "target")
        XCTAssertEqual(outcome, .clipboardFallback)
    }
}

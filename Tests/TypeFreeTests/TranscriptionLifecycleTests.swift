import XCTest
@testable import TypeFree

final class TranscriptionLifecycleTests: XCTestCase {

    func testStopCompletesWithFinalResultWhenFinalTranscriptArrives() {
        let lifecycle = TranscriptionLifecycle()
        var completedTexts: [String] = []

        lifecycle.receiveResult(text: "hel", isFinal: false)
        lifecycle.requestStop { completedTexts.append($0) }
        lifecycle.receiveResult(text: "hello", isFinal: true)

        XCTAssertEqual(completedTexts, ["hello"])
        XCTAssertEqual(lifecycle.latestText, "hello")
    }

    func testStopFallsBackToLatestPartialWhenTimeoutFires() {
        let lifecycle = TranscriptionLifecycle()
        var completedTexts: [String] = []

        lifecycle.receiveResult(text: "hello wor", isFinal: false)
        lifecycle.requestStop { completedTexts.append($0) }
        lifecycle.timeoutFired()

        XCTAssertEqual(completedTexts, ["hello wor"])
        XCTAssertTrue(lifecycle.isCompleted)
    }

    func testLateResultsAreIgnoredAfterCompletion() {
        let lifecycle = TranscriptionLifecycle()
        var completedTexts: [String] = []

        lifecycle.receiveResult(text: "hello", isFinal: false)
        lifecycle.requestStop { completedTexts.append($0) }
        lifecycle.timeoutFired()
        lifecycle.receiveResult(text: "hello world", isFinal: true)

        XCTAssertEqual(completedTexts, ["hello"])
        XCTAssertEqual(lifecycle.latestText, "hello")
    }
}

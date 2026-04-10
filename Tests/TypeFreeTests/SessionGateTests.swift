import XCTest
@testable import TypeFree

final class SessionGateTests: XCTestCase {

    func testOnlyLatestSessionCanRunSideEffects() {
        let gate = SessionGate()
        let first = gate.beginSession()
        let second = gate.beginSession()
        var values: [String] = []

        gate.runIfCurrent(first) {
            values.append("old")
        }
        gate.runIfCurrent(second) {
            values.append("new")
        }

        XCTAssertEqual(values, ["new"])
        XCTAssertFalse(gate.isCurrent(first))
        XCTAssertTrue(gate.isCurrent(second))
    }
}

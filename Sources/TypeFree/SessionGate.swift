import Foundation

/// Guards side effects so only the latest session may update UI or inject text.
final class SessionGate {

    private(set) var currentSessionID = 0

    func beginSession() -> Int {
        currentSessionID += 1
        return currentSessionID
    }

    func isCurrent(_ sessionID: Int) -> Bool {
        currentSessionID == sessionID
    }

    func runIfCurrent(_ sessionID: Int, _ action: () -> Void) {
        guard isCurrent(sessionID) else { return }
        action()
    }
}

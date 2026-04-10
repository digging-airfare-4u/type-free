import Foundation

/// Coordinates stop behavior so we can wait briefly for a final transcript
/// and still fall back to the latest partial result when needed.
final class TranscriptionLifecycle {

    private var stopCompletion: ((String) -> Void)?

    private(set) var latestText = ""
    private(set) var isStopRequested = false
    private(set) var isCompleted = false

    func receiveResult(text: String, isFinal: Bool) {
        guard !isCompleted else { return }

        latestText = text

        guard isStopRequested, isFinal else { return }
        complete()
    }

    func requestStop(completion: @escaping (String) -> Void) {
        guard !isCompleted else {
            completion(latestText)
            return
        }

        isStopRequested = true
        stopCompletion = completion
    }

    func receiveError() {
        guard isStopRequested else { return }
        complete()
    }

    func timeoutFired() {
        complete()
    }

    private func complete() {
        guard !isCompleted else { return }

        isCompleted = true
        let completion = stopCompletion
        stopCompletion = nil
        completion?(latestText)
    }
}

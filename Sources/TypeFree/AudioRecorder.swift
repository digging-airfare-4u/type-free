import AVFoundation
import Speech

/// Manages audio recording with streaming speech recognition and RMS metering.
final class AudioRecorder {

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var recognizer: SFSpeechRecognizer?
    private var lifecycle = TranscriptionLifecycle()
    private var stopCompletion: ((String) -> Void)?
    private var stopTimeoutWorkItem: DispatchWorkItem?
    private let stopGracePeriod: TimeInterval = 0.35

    /// Start recording with streaming transcription.
    @discardableResult
    func start(
        language: String,
        partialHandler: @escaping (String) -> Void,
        rmsHandler: @escaping (Float) -> Void
    ) -> Bool {
        lifecycle = TranscriptionLifecycle()
        stopCompletion = nil
        stopTimeoutWorkItem?.cancel()
        stopTimeoutWorkItem = nil

        let locale = Locale(identifier: language)
        recognizer = SFSpeechRecognizer(locale: locale)

        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("[TypeFree] Speech recognizer not available for \(language)")
            return false
        }

        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let request = recognitionRequest else { return false }

        request.shouldReportPartialResults = true
        if #available(macOS 15, *) {
            request.addsPunctuation = true
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            // Feed to speech recognizer
            self?.recognitionRequest?.append(buffer)

            // Calculate RMS for waveform visualization
            let rms = Self.calculateRMS(buffer: buffer)
            rmsHandler(rms)
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }

            if let result = result {
                let text = result.bestTranscription.formattedString
                self.lifecycle.receiveResult(text: text, isFinal: result.isFinal)

                if !self.lifecycle.isStopRequested && !self.lifecycle.isCompleted {
                    partialHandler(text)
                }
            }

            if let error {
                print("[TypeFree] Speech recognition error: \(error)")
                self.lifecycle.receiveError()
            }
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            print("[TypeFree] Audio engine failed to start: \(error)")
            audioEngine.inputNode.removeTap(onBus: 0)
            recognitionRequest = nil
            recognitionTask?.cancel()
            recognitionTask = nil
            self.recognizer = nil
            return false
        }

        return true
    }

    /// Stop recording and complete with the best available transcription.
    func stop(completion: @escaping (String) -> Void) {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()

        stopCompletion = completion
        lifecycle.requestStop { [weak self] text in
            self?.finishStop(with: text)
        }

        let timeoutWorkItem = DispatchWorkItem { [weak self] in
            self?.lifecycle.timeoutFired()
        }
        stopTimeoutWorkItem = timeoutWorkItem

        recognitionRequest?.endAudio()
        DispatchQueue.main.asyncAfter(deadline: .now() + stopGracePeriod, execute: timeoutWorkItem)
    }

    private func finishStop(with text: String) {
        stopTimeoutWorkItem?.cancel()
        stopTimeoutWorkItem = nil

        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        recognizer = nil

        let completion = stopCompletion
        stopCompletion = nil
        completion?(text)
    }

    /// Calculate RMS (root mean square) level from an audio buffer.
    private static func calculateRMS(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }
        let frames = Int(buffer.frameLength)
        guard frames > 0 else { return 0 }

        var sum: Float = 0
        let data = channelData[0]
        for i in 0..<frames {
            let sample = data[i]
            sum += sample * sample
        }

        let rms = sqrt(sum / Float(frames))
        // Convert to a 0-1 range (typical speech RMS is 0.01-0.3)
        let normalized = min(1.0, rms / 0.15)
        return normalized
    }
}

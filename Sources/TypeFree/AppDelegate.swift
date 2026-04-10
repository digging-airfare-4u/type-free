import Cocoa
import Speech

final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem!
    private let fnListener = FnKeyListener()
    private let recorder = AudioRecorder()
    private let overlay = CapsuleOverlay()
    private let injector = TextInjector()
    private let llm = LLMService()
    private let recordingSessions = SessionGate()

    private var isRecording = false
    private var refineDemoSequence = 0
    private var activeRecordingSessionID = 0

    // MARK: - Language

    static let languages: [(id: String, label: String)] = [
        ("en-US", "English"),
        ("zh-Hans", "简体中文"),
        ("zh-Hant", "繁體中文"),
        ("ja-JP", "日本語"),
        ("ko-KR", "한국어"),
    ]

    static var currentLanguage: String {
        get { UserDefaults.standard.string(forKey: "selectedLanguage") ?? "zh-Hans" }
        set { UserDefaults.standard.set(newValue, forKey: "selectedLanguage") }
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        requestPermissions()
        fnListener.onFnDown = { [weak self] in
            DispatchQueue.main.async { self?.startRecording() }
        }
        fnListener.onFnUp = { [weak self] in
            DispatchQueue.main.async { self?.stopRecording() }
        }
        fnListener.start()
    }

    // MARK: - Permissions

    private func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { status in
            if status != .authorized {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Speech Recognition Permission Required"
                    alert.informativeText = "Please grant Speech Recognition permission in System Settings > Privacy & Security."
                    alert.runModal()
                }
            }
        }
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            if !granted {
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Microphone Permission Required"
                    alert.informativeText = "Please grant Microphone permission in System Settings > Privacy & Security."
                    alert.runModal()
                }
            }
        }
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: "TypeFree")
        }
        rebuildMenu()
    }

    private func rebuildMenu() {
        let menu = NSMenu()

        // Language submenu
        let langItem = NSMenuItem(title: "Language", action: nil, keyEquivalent: "")
        let langMenu = NSMenu()
        for lang in Self.languages {
            let item = NSMenuItem(title: lang.label, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = lang.id
            item.state = (lang.id == Self.currentLanguage) ? .on : .off
            langMenu.addItem(item)
        }
        langItem.submenu = langMenu
        menu.addItem(langItem)

        // LLM Refinement submenu
        let llmItem = NSMenuItem(title: "LLM Refinement", action: nil, keyEquivalent: "")
        let llmMenu = NSMenu()

        let enableItem = NSMenuItem(
            title: LLMService.isEnabled ? "Disable" : "Enable",
            action: #selector(toggleLLM(_:)),
            keyEquivalent: ""
        )
        enableItem.target = self
        llmMenu.addItem(enableItem)

        let statusLabel: String
        if LLMService.isEnabled {
            statusLabel = LLMService.isConfigured ? "Status: Configured" : "Status: Not Configured"
        } else {
            statusLabel = "Status: Disabled"
        }
        let statusItem = NSMenuItem(title: statusLabel, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        llmMenu.addItem(statusItem)

        llmMenu.addItem(NSMenuItem.separator())

        let settingsItem = NSMenuItem(title: "Settings...", action: #selector(openLLMSettings(_:)), keyEquivalent: "")
        settingsItem.target = self
        llmMenu.addItem(settingsItem)

        llmMenu.addItem(NSMenuItem.separator())

        let debugDemoItem = NSMenuItem(title: "Debug Refine Demo", action: #selector(runRefineDemo(_:)), keyEquivalent: "")
        debugDemoItem.target = self
        llmMenu.addItem(debugDemoItem)

        llmItem.submenu = llmMenu
        menu.addItem(llmItem)

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit TypeFree", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func selectLanguage(_ sender: NSMenuItem) {
        guard let langId = sender.representedObject as? String else { return }
        Self.currentLanguage = langId
        rebuildMenu()
    }

    @objc private func toggleLLM(_ sender: NSMenuItem) {
        LLMService.isEnabled.toggle()
        rebuildMenu()
    }

    @objc private func openLLMSettings(_ sender: NSMenuItem) {
        LLMSettingsWindow.shared.show()
    }

    @objc private func runRefineDemo(_ sender: NSMenuItem) {
        guard !isRecording else { return }

        refineDemoSequence += 1
        let sequence = refineDemoSequence

        let rawText = "今天下午三点我们开会讨论 api 设计和 typescript 类型定义"

        overlay.show()
        overlay.hideRefining()
        overlay.updateText(rawText, animated: false)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) { [weak self] in
            guard let self, self.refineDemoSequence == sequence else { return }
            self.overlay.showRefining()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
            guard let self, self.refineDemoSequence == sequence else { return }
            self.overlay.dismiss()
        }
    }

    // MARK: - Recording Flow

    private func startRecording() {
        guard !isRecording else { return }

        let sessionID = recordingSessions.beginSession()
        activeRecordingSessionID = sessionID

        overlay.show()
        let didStart = recorder.start(language: Self.currentLanguage) { [weak self] partial in
            DispatchQueue.main.async {
                guard let self else { return }
                self.recordingSessions.runIfCurrent(sessionID) {
                    self.overlay.updateText(partial)
                }
            }
        } rmsHandler: { [weak self] rms in
            DispatchQueue.main.async {
                guard let self else { return }
                self.recordingSessions.runIfCurrent(sessionID) {
                    self.overlay.updateRMS(rms)
                }
            }
        }

        guard didStart else {
            overlay.dismiss()
            return
        }

        isRecording = true
    }

    private func stopRecording() {
        guard isRecording else { return }
        isRecording = false
        let sessionID = activeRecordingSessionID

        recorder.stop { [weak self] rawText in
            DispatchQueue.main.async {
                guard let self else { return }
                self.recordingSessions.runIfCurrent(sessionID) {
                    self.handleCompletedRecording(rawText, sessionID: sessionID)
                }
            }
        }
    }

    private func handleCompletedRecording(_ rawText: String, sessionID: Int) {
        if rawText.isEmpty {
            recordingSessions.runIfCurrent(sessionID) {
                overlay.dismiss()
            }
            return
        }

        if LLMService.isEnabled && LLMService.isConfigured {
            recordingSessions.runIfCurrent(sessionID) {
                overlay.showRefining()
            }

            llm.refine(text: rawText, language: Self.currentLanguage) { [weak self] refined in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.recordingSessions.runIfCurrent(sessionID) {
                        let finalText = refined ?? rawText
                        self.overlay.dismiss(afterDelay: 0.08)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
                            guard let self else { return }
                            self.recordingSessions.runIfCurrent(sessionID) {
                                self.injector.inject(text: finalText)
                            }
                        }
                    }
                }
            }
        } else {
            recordingSessions.runIfCurrent(sessionID) {
                overlay.dismiss(afterDelay: 0.2)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                    guard let self else { return }
                    self.recordingSessions.runIfCurrent(sessionID) {
                        self.injector.inject(text: rawText)
                    }
                }
            }
        }
    }
}

import Cocoa

/// Settings window for LLM Refinement configuration.
final class LLMSettingsWindow {

    static let shared = LLMSettingsWindow()

    private var window: NSWindow?
    private var baseURLField: NSTextField!
    private var apiKeyField: NSSecureTextField!
    private var modelField: NSTextField!
    private var statusLabel: NSTextField!
    private var testButton: NSButton!
    private var saveButton: NSButton!

    func show() {
        if let existing = window, existing.isVisible {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let w: CGFloat = 480
        let h: CGFloat = 280

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: w, height: h),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "LLM Refinement Settings"
        window.center()
        window.isReleasedWhenClosed = false

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: w, height: h))

        let margin: CGFloat = 20
        let labelWidth: CGFloat = 110
        let fieldX = margin + labelWidth + 8
        let fieldWidth = w - fieldX - margin
        var y = h - 50

        // API Base URL
        let baseLabel = makeLabel("API Base URL:", frame: NSRect(x: margin, y: y, width: labelWidth, height: 22))
        contentView.addSubview(baseLabel)
        baseURLField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        baseURLField.placeholderString = "https://api.openai.com/v1"
        baseURLField.stringValue = LLMService.apiBaseURL
        contentView.addSubview(baseURLField)

        y -= 36

        // API Key
        let keyLabel = makeLabel("API Key:", frame: NSRect(x: margin, y: y, width: labelWidth, height: 22))
        contentView.addSubview(keyLabel)
        apiKeyField = NSSecureTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        apiKeyField.placeholderString = "sk-..."
        apiKeyField.stringValue = LLMService.apiKey
        contentView.addSubview(apiKeyField)

        y -= 36

        // Model
        let modelLabel = makeLabel("Model:", frame: NSRect(x: margin, y: y, width: labelWidth, height: 22))
        contentView.addSubview(modelLabel)
        modelField = NSTextField(frame: NSRect(x: fieldX, y: y, width: fieldWidth, height: 22))
        modelField.placeholderString = "gpt-4o-mini"
        modelField.stringValue = LLMService.model
        contentView.addSubview(modelField)

        y -= 44

        // Status label
        statusLabel = NSTextField(labelWithString: "")
        statusLabel.frame = NSRect(x: margin, y: y, width: w - 2 * margin, height: 22)
        statusLabel.font = NSFont.systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        contentView.addSubview(statusLabel)

        y -= 40

        // Buttons
        let buttonWidth: CGFloat = 80
        let buttonSpacing: CGFloat = 12

        saveButton = NSButton(title: "Save", target: self, action: #selector(save))
        saveButton.frame = NSRect(x: w - margin - buttonWidth, y: y, width: buttonWidth, height: 28)
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        contentView.addSubview(saveButton)

        testButton = NSButton(title: "Test", target: self, action: #selector(test))
        testButton.frame = NSRect(x: w - margin - buttonWidth * 2 - buttonSpacing, y: y, width: buttonWidth, height: 28)
        testButton.bezelStyle = .rounded
        contentView.addSubview(testButton)

        window.contentView = contentView
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
    }

    private func makeLabel(_ text: String, frame: NSRect) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.frame = frame
        label.alignment = .right
        label.font = NSFont.systemFont(ofSize: 13)
        return label
    }

    @objc private func save() {
        LLMService.apiBaseURL = baseURLField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        LLMService.apiKey = apiKeyField.stringValue
        LLMService.model = modelField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        statusLabel.stringValue = "Settings saved."
        statusLabel.textColor = .systemGreen
    }

    @objc private func test() {
        save()
        statusLabel.stringValue = "Testing..."
        statusLabel.textColor = .secondaryLabelColor
        testButton.isEnabled = false

        let service = LLMService()
        service.testConnection { [weak self] success, message in
            DispatchQueue.main.async {
                self?.statusLabel.stringValue = message
                self?.statusLabel.textColor = success ? .systemGreen : .systemRed
                self?.testButton.isEnabled = true
            }
        }
    }
}

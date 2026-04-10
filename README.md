# TypeFree

A lightweight macOS menu bar application for voice-to-text transcription. Press Fn, speak, and your words are automatically transcribed and injected into any active text field.

[中文说明](README.zh.md)

## Features

- **Real-time Voice Transcription** — Press Fn key to start recording. See live transcription in a floating overlay panel.
- **Apple Speech Recognition** — Uses native macOS `SFSpeechRecognizer` for fast, on-device transcription.
- **Optional LLM Refinement** — Optionally refine transcriptions through an OpenAI-compatible API endpoint.
- **Smart Text Injection** — Automatically pastes transcribed text into the active text field.
- **CJK Input Method Support** — Detects and properly handles Chinese, Japanese, and Korean input methods.
- **Waveform Visualization** — 60fps animated waveform display during recording.
- **Menu Bar Integration** — Runs quietly in the macOS menu bar; minimize, customize, and control from the top menu.

## System Requirements

- **macOS 14.0+** (Sonoma or later)
- **Swift 5.9+**
- **Audio recording permissions** — First run will prompt for microphone access
- **Accessibility permissions** — Required for global Fn key detection and text field interaction

## Installation

### From Source

1. **Clone the repository:**
   ```bash
   git clone git@github.com:digging-airfare-4u/type-free.git
   cd type-free
   ```

2. **Build the application:**
   ```bash
   make build
   ```

3. **Install to Applications folder:**
   ```bash
   make install
   ```

4. **Launch TypeFree:**
   - Open **Applications** → **TypeFree**
   - Grant microphone and accessibility permissions when prompted
   - The app will appear in the menu bar

## Usage

1. **Start Recording:** Press the **Fn key** (Function key) on your keyboard
2. **Speak:** The waveform overlay will appear and display real-time transcription
3. **Stop Recording:** Release the **Fn key**
4. **Paste:** The transcribed text is automatically injected into the active text field

### Settings

- Click the TypeFree menu bar icon → **Settings**
- Configure LLM API endpoint (if using text refinement)
- Adjust transcription language and other preferences

## Development

### Build Commands

```bash
swift build -c release       # Build release binary
make build                   # Build and create .app bundle
make run                     # Build and launch immediately
make install                 # Copy .app to /Applications
make clean                   # Remove build artifacts
swift test                   # Run all tests
swift test --filter <TestClass/testMethod>  # Run specific test
```

### Project Structure

```
Sources/TypeFree/
├── main.swift                    # Entry point
├── AppDelegate.swift             # Main coordinator & status bar
├── AudioRecorder.swift           # Audio capture & speech recognition
├── FnKeyListener.swift           # Global Fn key detection
├── TextInjector.swift            # Text injection with CJK support
├── CapsuleOverlay.swift          # Floating overlay UI & waveform
├── SessionGate.swift             # Race condition prevention
├── TranscriptionLifecycle.swift  # Stop timing & fallback logic
├── LLMService.swift              # OpenAI API integration
└── LLMSettingsWindow.swift       # Settings UI

Tests/TypeFreeTests/
├── LLMServiceTests.swift
├── SessionGateTests.swift
└── TranscriptionLifecycleTests.swift
```

### Key Architecture Concepts

- **SessionGate** — Prevents race conditions by tracking session IDs. All UI updates and text injection are guarded.
- **TranscriptionLifecycle** — Manages stop timing with a 0.35s grace period for final transcript results.
- **CJK Input Handling** — Automatically switches to ASCII input method, injects text, then restores the original method.
- **LLM Language Awareness** — Uses specialized Chinese prompts for zh-Hans/zh-Hant; generic English for others.
- **Threading** — UI updates on main queue; audio and speech recognition on dedicated queues.

## Configuration

TypeFree stores settings in:
- **Preferences:** `~/Library/Preferences/com.typefree.TypeFree.plist`
- **LLM Settings:** Accessible via the menu bar Settings window

### LLM API Setup (Optional)

1. Open TypeFree → **Settings**
2. Enter your **OpenAI-compatible API endpoint** (e.g., `https://api.openai.com/v1/chat/completions`)
3. Provide your **API key**
4. Choose your **model** (e.g., `gpt-4`, `gpt-3.5-turbo`)

TypeFree will automatically refine transcriptions when LLM is configured.

## Troubleshooting

### Microphone Access Denied

- Open **System Settings** → **Privacy & Security** → **Microphone**
- Ensure TypeFree is in the allowed list

### Fn Key Not Detected

- Ensure TypeFree has **Accessibility** permissions
- Open **System Settings** → **Privacy & Security** → **Accessibility**
- Add TypeFree to the allowed list

### Text Not Injecting

- Verify the target application supports clipboard text injection
- Check that the text field is focused before pressing Fn
- Some applications may have security restrictions

## License

This project is provided as-is for personal use.

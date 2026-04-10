# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

TypeFree is a macOS menu bar application (macOS 14.0+, Swift 5.9+) for voice-to-text transcription. It records audio via Fn key press, transcribes using Apple's Speech Recognition framework, optionally refines text through an OpenAI-compatible LLM API, and injects the result into any active text field.

## Build & Development Commands

```bash
swift build -c release    # Build release binary
make build                # Build and create .app bundle
make run                  # Build and launch
make install              # Copy .app to /Applications
make clean                # Remove build artifacts

swift test                # Run all tests
swift test --filter <TestClass/testMethod>  # Run a single test
```

The app is ad-hoc code signed with runtime hardening via the Makefile.

## Architecture

**Data flow:** Fn key press → AudioRecorder (AVAudioEngine + SFSpeechRecognizer streaming) → partial results shown in CapsuleOverlay → Fn release triggers stop → optional LLM refinement → TextInjector pastes into active field.

**Key design decisions:**

- **SessionGate** — Session IDs prevent race conditions when Fn is pressed again during active recording. All UI updates and text injection go through `SessionGate.runIfCurrent()`.
- **TranscriptionLifecycle** — Coordinates stop timing with a 0.35s grace period for final transcript before falling back to the last partial result.
- **CJK input method handling** — TextInjector detects CJK input sources (Apple SCIM, Google IME, Sogou, etc.), temporarily switches to ASCII before paste, waits 50ms, then restores the original input source.
- **LLM language-aware prompts** — Specialized Chinese system prompt for zh-Hans/zh-Hant; generic English prompt for all other languages. Response sanitization strips `<think>...</think>` blocks.
- **Waveform animation** — Uses CVDisplayLink for 60fps rendering with RMS-based amplitude (normalized 0–1).

**Threading:** All UI updates are dispatched to main queue. Audio processing and speech recognition run on their own queues.

## Source Layout

All source files are in `Sources/TypeFree/`. Tests are in `Tests/TypeFreeTests/` using XCTest. LLM HTTP tests use a `URLProtocolStub` for mocking.

## Key Files

- `AppDelegate.swift` — Main coordinator: status bar, menu, recording flow orchestration
- `AudioRecorder.swift` — AVAudioEngine + SFSpeechRecognizer streaming setup
- `FnKeyListener.swift` — Global Fn key detection via CGEvent tap
- `TextInjector.swift` — Clipboard-based text injection with CJK input source switching
- `CapsuleOverlay.swift` — Floating overlay panel with waveform visualization
- `SessionGate.swift` — Guards against stale session updates
- `TranscriptionLifecycle.swift` — Stop timing, timeout, and fallback behavior

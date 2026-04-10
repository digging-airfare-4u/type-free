import Cocoa
import Carbon

/// Injects text into the currently focused input field via clipboard + Cmd+V.
/// Handles CJK input method switching to prevent interception.
final class TextInjector {

    func inject(text: String) {
        guard !text.isEmpty else { return }

        // 1. Save current clipboard contents
        let pasteboard = NSPasteboard.general
        let savedItems = savePasteboard(pasteboard)

        // 2. Set new text on clipboard
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // 3. Check if current input source is CJK and switch if needed
        let originalSource = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let needsSwitch = isCJKInputSource(originalSource)
        if needsSwitch {
            switchToASCIIInput()
            // Small delay to let input source switch take effect
            usleep(50_000) // 50ms
        }

        // 4. Simulate Cmd+V
        simulatePaste()

        // 5. Restore original input source if we switched
        if needsSwitch {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                TISSelectInputSource(originalSource)
            }
        }

        // 6. Restore clipboard after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.restorePasteboard(pasteboard, items: savedItems)
        }
    }

    // MARK: - Input Source Detection

    private func isCJKInputSource(_ source: TISInputSource) -> Bool {
        guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else {
            return false
        }
        let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

        let cjkPrefixes = [
            "com.apple.inputmethod.SCIM",       // Simplified Chinese
            "com.apple.inputmethod.TCIM",       // Traditional Chinese
            "com.apple.inputmethod.Korean",     // Korean
            "com.apple.inputmethod.Japanese",   // Japanese
            "com.apple.inputmethod.ChineseHandwriting",
            "com.google.inputmethod.Japanese",
            "com.sogou.inputmethod",
            "com.baidu.inputmethod",
            "com.tencent.inputmethod",
        ]

        return cjkPrefixes.contains(where: { sourceID.hasPrefix($0) })
    }

    private func switchToASCIIInput() {
        guard let sources = TISCreateInputSourceList(
            [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary,
            false
        )?.takeRetainedValue() as? [TISInputSource] else { return }

        // Prefer "ABC" or "US" keyboard
        for source in sources {
            guard let idPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceID) else { continue }
            let sourceID = Unmanaged<CFString>.fromOpaque(idPtr).takeUnretainedValue() as String

            if sourceID == "com.apple.keylayout.ABC" || sourceID == "com.apple.keylayout.US" {
                TISSelectInputSource(source)
                return
            }
        }

        // Fallback: select any ASCII-capable source
        for source in sources {
            guard let asciiPtr = TISGetInputSourceProperty(source, kTISPropertyInputSourceIsASCIICapable) else { continue }
            let isASCII = Unmanaged<CFBoolean>.fromOpaque(asciiPtr).takeUnretainedValue()
            if CFBooleanGetValue(isASCII) {
                TISSelectInputSource(source)
                return
            }
        }
    }

    // MARK: - Simulate Paste

    private func simulatePaste() {
        let vKeyCode: CGKeyCode = 9  // 'v' key

        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: true)
        keyDown?.flags = .maskCommand
        keyDown?.post(tap: .cgAnnotatedSessionEventTap)

        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: vKeyCode, keyDown: false)
        keyUp?.flags = .maskCommand
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }

    // MARK: - Pasteboard Save/Restore

    private struct PasteboardItem {
        let type: NSPasteboard.PasteboardType
        let data: Data
    }

    private func savePasteboard(_ pb: NSPasteboard) -> [PasteboardItem] {
        var items: [PasteboardItem] = []
        guard let types = pb.types else { return items }
        for type in types {
            if let data = pb.data(forType: type) {
                items.append(PasteboardItem(type: type, data: data))
            }
        }
        return items
    }

    private func restorePasteboard(_ pb: NSPasteboard, items: [PasteboardItem]) {
        guard !items.isEmpty else { return }
        pb.clearContents()
        for item in items {
            pb.setData(item.data, forType: item.type)
        }
    }
}

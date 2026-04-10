import Cocoa

/// Listens for global Fn key press/release via CGEvent tap.
/// Suppresses the event so macOS doesn't open the emoji picker.
final class FnKeyListener {

    var onFnDown: (() -> Void)?
    var onFnUp: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var fnDown = false
    private var permissionTimer: Timer?

    /// Virtual keycode for the Fn/Globe key.
    static let fnKeyCode: Int64 = 63

    func start() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        if AXIsProcessTrustedWithOptions(options) {
            createEventTap()
        } else {
            // Poll until permission is granted
            permissionTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    timer.invalidate()
                    self?.permissionTimer = nil
                    self?.createEventTap()
                }
            }
        }
    }

    private func createEventTap() {
        let mask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)
            | (1 << CGEventType.keyDown.rawValue)
            | (1 << CGEventType.keyUp.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: fnEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Cannot Listen for Fn Key"
                alert.informativeText = "Failed to create event tap. Please ensure TypeFree is allowed in System Settings > Privacy & Security > Accessibility, then relaunch the app."
                alert.runModal()
            }
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        permissionTimer?.invalidate()
        permissionTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleEvent(_ proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> CGEvent? {
        // Re-enable tap if it gets disabled by the system
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return event
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags

        if type == .flagsChanged {
            // Detect Fn/Globe key by keycode 63 OR by the secondaryFn flag
            let isFnKeyCode = (keyCode == Self.fnKeyCode)
            let fnFlagSet = flags.contains(.maskSecondaryFn)

            if isFnKeyCode || (fnFlagSet && !fnDown) {
                // Check no other modifiers held
                let significantModifiers: CGEventFlags = [.maskShift, .maskControl, .maskAlternate, .maskCommand]
                let hasOtherModifiers = !flags.intersection(significantModifiers).isEmpty

                if fnFlagSet && !fnDown && !hasOtherModifiers {
                    fnDown = true
                    onFnDown?()
                    return nil  // suppress to prevent emoji picker
                } else if !fnFlagSet && fnDown {
                    fnDown = false
                    onFnUp?()
                    return nil  // suppress
                }
            }

            return event
        }

        // If Fn is held, suppress key events to prevent system behavior
        if fnDown && (type == .keyDown || type == .keyUp) {
            return nil
        }

        return event
    }
}

private func fnEventCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
    let listener = Unmanaged<FnKeyListener>.fromOpaque(userInfo).takeUnretainedValue()
    if let result = listener.handleEvent(proxy, type: type, event: event) {
        return Unmanaged.passRetained(result)
    }
    return nil
}

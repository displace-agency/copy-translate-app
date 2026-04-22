import AppKit

/// Global ⌘C double-tap detector. Uses a CGEventTap so it works in any app
/// that has a selection. Requires Accessibility permission in System
/// Settings > Privacy & Security > Accessibility.
final class EventTap {
    typealias Handler = () -> Void

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var lastTapAt: TimeInterval = 0
    private let window: TimeInterval
    private let onDoubleTap: Handler

    init(window: TimeInterval, onDoubleTap: @escaping Handler) {
        self.window = window
        self.onDoubleTap = onDoubleTap
    }

    /// Returns true when the tap installed successfully. Returns false when
    /// Accessibility permission is missing; in that case the caller should
    /// prompt the user via AXIsProcessTrustedWithOptions.
    @discardableResult
    func start() -> Bool {
        let mask = (1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: CGEventMask(mask),
            callback: { _, type, event, refcon in
                guard let refcon else { return Unmanaged.passUnretained(event) }
                let tap = Unmanaged<EventTap>.fromOpaque(refcon).takeUnretainedValue()
                tap.handle(type: type, event: event)
                return Unmanaged.passUnretained(event)
            },
            userInfo: refcon
        ) else { return false }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    func stop() {
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let tap = tap { CGEvent.tapEnable(tap: tap, enable: false) }
        tap = nil
        runLoopSource = nil
    }

    private func handle(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return
        }
        guard type == .keyDown else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        let flags = event.flags
        // kVK_ANSI_C = 8
        guard keyCode == 8, flags.contains(.maskCommand) else { return }
        // Ignore ⇧/⌃/⌥+⌘+C combos — only bare ⌘C.
        if flags.contains(.maskShift) || flags.contains(.maskControl) || flags.contains(.maskAlternate) {
            return
        }

        let now = CFAbsoluteTimeGetCurrent()
        if now - lastTapAt <= window {
            lastTapAt = 0
            DispatchQueue.main.async { [weak self] in self?.onDoubleTap() }
        } else {
            lastTapAt = now
        }
    }
}

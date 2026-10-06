import CoreGraphics
import Foundation

@MainActor
protocol KeyboardListening: AnyObject {
    var onKeyDown: ((Int64) -> Void)? { get set }
    var onDisabled: (() -> Void)? { get set }
    func start() -> Bool
    func stop()
}

@MainActor
final class KeyboardMonitor: KeyboardListening {
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    var onKeyDown: ((Int64) -> Void)?
    var onDisabled: (() -> Void)?

    private var isRunning: Bool {
        guard let tap else { return false }
        return CFMachPortIsValid(tap) && CGEvent.tapIsEnabled(tap: tap)
    }

    func start() -> Bool {
        if isRunning { return true }
        stop()
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: { _, type, event, userInfo in
                guard let userInfo else { return Unmanaged.passUnretained(event) }
                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
                // This source is installed exclusively on the main run loop.
                MainActor.assumeIsolated { monitor.receive(type: type, event: event) }
                return Unmanaged.passUnretained(event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }
        guard let newSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0) else {
            CFMachPortInvalidate(newTap)
            return false
        }
        tap = newTap
        source = newSource
        CFRunLoopAddSource(CFRunLoopGetMain(), newSource, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)
        guard isRunning else {
            stop()
            return false
        }
        return true
    }

    private func receive(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            // Recovery may rebuild the tap, so defer only this lifecycle work.
            DispatchQueue.main.async { [weak self] in self?.onDisabled?() }
            return
        }
        guard type == .keyDown, isRunning else { return }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard KeySoundRouter.kind(for: keyCode,
                                  isRepeat: event.getIntegerValueField(.keyboardEventAutorepeat) != 0) != nil
        else { return }
        // Submit a preloaded voice immediately. Core Audio renders it asynchronously;
        // no per-keystroke dispatch, disk I/O, or wait for an earlier sound to finish.
        // The hardware code selects a sound; no characters or key history are kept.
        onKeyDown?(keyCode)
    }

    func stop() {
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
        source = nil
        tap = nil
    }

    deinit {
        if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
        if let tap { CFMachPortInvalidate(tap) }
    }
}

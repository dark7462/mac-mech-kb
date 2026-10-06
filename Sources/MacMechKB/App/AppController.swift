import AppKit
import Combine

@MainActor
final class AppController: ObservableObject {
    enum Status: Equatable {
        case playing, paused, sleeping, needsPermission, listenerUnavailable
        case audioUnavailable(String)

        var title: String {
            switch self {
            case .playing: return "Playing"
            case .paused: return "Paused"
            case .sleeping: return "Paused while Mac sleeps"
            case .needsPermission: return "Input Monitoring needed"
            case .listenerUnavailable: return "Keyboard listener unavailable"
            case .audioUnavailable: return "Audio unavailable"
            }
        }

        var recoveryMessage: String? {
            switch self {
            case .listenerUnavailable:
                return "Check Input Monitoring in System Settings, then restart the app or retry."
            case .audioUnavailable(let message): return message
            default: return nil
            }
        }
    }

    let settings: SettingsStore
    @Published private(set) var status: Status = .paused
    @Published private(set) var hasKeyboardAccess = false
    private let permission: PermissionChecking
    private let monitor: KeyboardListening
    private let audio: SoundPlaying
    private var sleeping = false
    private var observations = Set<AnyCancellable>()

    convenience init() {
        self.init(settings: SettingsStore(), permission: PermissionManager(),
                  monitor: KeyboardMonitor(), audio: SoundEngine())
        observeSystemEvents()
    }

    init(settings: SettingsStore, permission: PermissionChecking,
         monitor: KeyboardListening, audio: SoundPlaying) {
        self.settings = settings
        self.permission = permission
        self.monitor = monitor
        self.audio = audio
        monitor.onKeyDown = { [weak self] keyCode in
            guard let self, self.status == .playing else { return }
            self.audio.play(keyCode: keyCode)
        }
        monitor.onDisabled = { [weak self] in self?.refresh() }
        audio.onConfigurationChange = { [weak self] in self?.refresh() }
        refresh()
    }

    private func observeSystemEvents() {
        // Permission revocation must be noticed even when the menu stays closed.
        Timer.publish(every: 2, tolerance: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &observations)
        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.refresh() }
            .store(in: &observations)
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.publisher(for: NSWorkspace.willSleepNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.setSleeping(true) }
            .store(in: &observations)
        workspace.publisher(for: NSWorkspace.didWakeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.setSleeping(false) }
            .store(in: &observations)
    }

    func refresh() {
        permission.refresh()
        if hasKeyboardAccess != permission.granted { hasKeyboardAccess = permission.granted }
        guard settings.enabled else { stop(status: .paused); return }
        guard !sleeping else { stop(status: .sleeping); return }
        guard permission.granted else { stop(status: .needsPermission); return }
        do {
            try audio.load(settings.preset)
            audio.setLubed(settings.lubed)
            try audio.start(volume: settings.volume)
        } catch {
            stop(status: .audioUnavailable(error.localizedDescription))
            return
        }
        guard monitor.start() else { stop(status: .listenerUnavailable); return }
        updateStatus(.playing)
    }

    private func stop(status: Status) {
        monitor.stop()
        audio.stop()
        updateStatus(status)
    }

    private func updateStatus(_ value: Status) {
        if status != value { status = value }
    }

    func setSleeping(_ value: Bool) {
        sleeping = value
        refresh()
    }

    func setEnabled(_ enabled: Bool) {
        settings.setEnabled(enabled)
        refresh()
    }

    func setVolume(_ volume: Double) {
        settings.setVolume(volume)
        audio.setVolume(settings.volume)
    }

    func setLubed(_ enabled: Bool) {
        settings.setLubed(enabled)
        audio.setLubed(enabled)
    }

    func setPreset(_ preset: SoundPreset) {
        guard settings.preset != preset else { return }
        monitor.stop() // Stop receiving keys while replacing the preloaded pack.
        settings.setPreset(preset)
        refresh()
    }

    func requestPermission() {
        permission.request()
        refresh()
    }

    func openPermissionSettings() { permission.openSettings() }
}

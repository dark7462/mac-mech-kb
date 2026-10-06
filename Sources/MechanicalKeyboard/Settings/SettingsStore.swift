import Foundation
import Combine

enum SoundPreset: String, CaseIterable, Identifiable {
    case blue = "Blue"
    case brown = "Brown"
    case red = "Red"
    var id: String { rawValue }
}

@MainActor
final class SettingsStore: ObservableObject {
    @Published private(set) var enabled: Bool
    @Published private(set) var volume: Double
    @Published private(set) var preset: SoundPreset
    @Published private(set) var lubed: Bool

    private let defaults: UserDefaults
    private enum Keys {
        static let enabled = "enabled"
        static let volume = "volume"
        static let preset = "preset"
        static let lubed = "lubed"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        enabled = defaults.object(forKey: Keys.enabled) as? Bool ?? true
        volume = Self.validVolume(defaults.object(forKey: Keys.volume) as? Double ?? 0.6)
        preset = SoundPreset(rawValue: defaults.string(forKey: Keys.preset) ?? "") ?? .brown
        lubed = defaults.object(forKey: Keys.lubed) as? Bool ?? false
    }

    func setEnabled(_ value: Bool) {
        enabled = value
        defaults.set(value, forKey: Keys.enabled)
    }

    func setVolume(_ value: Double) {
        volume = Self.validVolume(value)
        defaults.set(volume, forKey: Keys.volume)
    }

    func setPreset(_ value: SoundPreset) {
        preset = value
        defaults.set(value.rawValue, forKey: Keys.preset)
    }

    func setLubed(_ value: Bool) {
        lubed = value
        defaults.set(value, forKey: Keys.lubed)
    }

    private static func validVolume(_ value: Double) -> Double {
        value.isFinite ? min(1, max(0, value)) : 0.6
    }
}

import AVFoundation
import Carbon.HIToolbox
import Combine
import Foundation
import ServiceManagement

// The CLI runner compiles production sources without SwiftPM's generated accessor.
// Engine tests use offline rendering and never open a device or register a login item.
extension Bundle { static var module: Bundle { .main } }

final class MemoryDefaults: UserDefaults {
    private var values: [String: Any] = [:]
    override func object(forKey key: String) -> Any? { values[key] }
    override func string(forKey key: String) -> String? { values[key] as? String }
    override func set(_ value: Any?, forKey key: String) { values[key] = value }
    override func set(_ value: Bool, forKey key: String) { values[key] = value }
    override func set(_ value: Double, forKey key: String) { values[key] = value }
}

struct Failure: Error, CustomStringConvertible {
    let description: String
}

@MainActor
final class FakePermission: PermissionChecking {
    var granted = false
    func refresh() {}
    func request() {}
    func openSettings() {}
}

@MainActor
final class FakeKeyboard: KeyboardListening {
    var onKeyDown: ((Int64) -> Void)?
    var onDisabled: (() -> Void)?
    var canStart = true
    var running = false
    var stops = 0
    func start() -> Bool { running = canStart; return running }
    func stop() { stops += 1; running = false }
}

@MainActor
final class FakeAudio: SoundPlaying {
    var onConfigurationChange: (() -> Void)?
    var failStart = false
    var failLoad = false
    var running = false
    var starts = 0
    var plays = 0
    var loaded: SoundPreset?
    var volume = 0.0
    func load(_ preset: SoundPreset) throws {
        if failLoad { throw Failure(description: "Missing sample") }
        loaded = preset
    }
    func start(volume: Double) throws {
        starts += 1
        if failStart { throw Failure(description: "Output disconnected") }
        self.volume = volume
        running = true
    }
    func setVolume(_ volume: Double) { self.volume = volume }
    func play(keyCode: Int64) { plays += 1 }
    var lubed = false
    func setLubed(_ enabled: Bool) { lubed = enabled }
    func stop() { running = false }
    func outputChanged() { running = false; onConfigurationChange?() }
}

@MainActor
final class FakeLogin: LoginService {
    var status: SMAppService.Status = .notRegistered
    var failRegistration = false
    func register() throws {
        if failRegistration { throw Failure(description: "Registration failed") }
        status = .requiresApproval
    }
    func unregister() throws { status = .notRegistered }
    func openSettings() {}
}

struct SeededRandom: RandomNumberGenerator {
    var state: UInt64 = 42
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@main
@MainActor
struct RegressionTests {
    static var checks = 0

    static func check(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        checks += 1
        guard condition() else { throw Failure(description: message) }
    }

    static func main() {
        do {
            try router()
            try variations()
            try settings()
            try lifecycle()
            try login()
            try soundPacks()
            try audioRendering()
            try lubeLoudness()
            if CommandLine.arguments.contains("--write-previews") { try writePreviews() }
            print("Passed \(checks) regression checks: routing, variations, preferences, lifecycle, login state, sound packs, and offline audio rendering.")
        } catch {
            fputs("FAIL: \(error)\n", stderr)
            exit(1)
        }
    }

    static func router() throws {
        for (code, kind) in [(49, SoundKind.space), (36, .enter), (76, .enter), (51, .backspace), (117, .backspace)] {
            try check(KeySoundRouter.kind(for: Int64(code), isRepeat: false) == kind, "Special-key classification")
        }
        for code: Int64 in 0...127 {
            try check(KeySoundRouter.kind(for: code, isRepeat: true) == nil, "Autorepeat must be silent")
        }
        // Includes the F3/F5/F20 codes the previous range-based filter missed.
        for code: Int64 in [54, 55, 56, 57, 58, 59, 60, 61, 62, 63, 64, 79, 80, 90,
                            96, 97, 98, 99, 100, 101, 103, 105, 106, 107, 109, 111,
                            113, 114, 115, 116, 118, 119, 120, 121, 122, 123, 124, 125, 126] {
            try check(KeySoundRouter.kind(for: code, isRepeat: false) == nil, "Modifier/function/navigation policy")
        }
        for code: Int64 in [0, 1, 12, 18, 48, 53, 65, 82, 93, 94, 95, 102, 104] {
            try check(KeySoundRouter.kind(for: code, isRepeat: false) == .normal, "Letters, tab, escape, keypad and international keys should sound")
        }
    }

    static func variations() throws {
        var random = SeededRandom()
        var firstChoices = Set<Int>()
        for _ in 0..<100 {
            var picker = SampleVariationPicker()
            firstChoices.insert(picker.nextIndex(count: 6, using: &random)!)
        }
        try check(firstChoices == Set(0..<6), "First sample must include variation zero")
        var picker = SampleVariationPicker()
        var previous: Int?
        for _ in 0..<1_000 {
            let next = picker.nextIndex(count: 6, using: &random)!
            try check((0..<6).contains(next) && next != previous, "Variation must be in range and avoid immediate repetition")
            previous = next
        }
        try check(picker.nextIndex(count: 1, using: &random) == 0, "Single sample fallback")
        try check(picker.nextIndex(count: 0, using: &random) == nil, "Empty pack must not index or crash")
        try check(picker.nextIndex(count: -1, using: &random) == nil, "Invalid pack size must not index or crash")
    }

    static func settings() throws {
        let defaults = MemoryDefaults()
        let store = SettingsStore(defaults: defaults)
        try check(store.enabled && store.volume == 0.6 && store.preset == .brown && !store.lubed, "Default preferences")
        var notifications = 0
        let observation = store.objectWillChange.sink { notifications += 1 }
        store.setEnabled(false)
        store.setVolume(0.37)
        store.setPreset(.red)
        store.setLubed(true)
        let restored = SettingsStore(defaults: defaults)
        try check(!restored.enabled && restored.volume == 0.37 && restored.preset == .red && restored.lubed, "Preferences survive store recreation")
        try check(notifications == 4, "Direct settings observation updates every control")
        withExtendedLifetime(observation) {}
        for (input, expected) in [(2.0, 1.0), (-1.0, 0.0), (Double.nan, 0.6), (Double.infinity, 0.6)] {
            store.setVolume(input)
            try check(store.volume == expected, "Volume validation prevents NaN UI/audio state")
            try check(SettingsStore(defaults: defaults).volume == expected, "Validated volume is persisted")
        }
        defaults.set(Double.nan, forKey: "volume")
        defaults.set("Unknown", forKey: "preset")
        try check(SettingsStore(defaults: defaults).volume == 0.6, "Invalid saved volume recovers")
        try check(SettingsStore(defaults: defaults).preset == .brown, "Unknown saved preset recovers")
    }

    static func lifecycle() throws {
        let store = SettingsStore(defaults: MemoryDefaults())
        let permission = FakePermission()
        let keyboard = FakeKeyboard()
        let audio = FakeAudio()
        let app = AppController(settings: store, permission: permission, monitor: keyboard, audio: audio)
        try check(app.status == .needsPermission && audio.starts == 0 && !keyboard.running, "Denied permission never starts capture/audio")
        permission.granted = true
        app.refresh()
        try check(app.status == .playing && audio.running && keyboard.running, "Later permission grant starts services")
        keyboard.onKeyDown?(0)
        try check(audio.plays == 1, "Active key produces a sound")
        app.setEnabled(false)
        let startsBefore = audio.starts
        audio.outputChanged()
        keyboard.onKeyDown?(0)
        try check(app.status == .paused && !audio.running && !keyboard.running && audio.starts == startsBefore && audio.plays == 1,
                  "Output changes and late events must not revive paused audio")
        app.setVolume(0.25)
        app.setLubed(true)
        app.setPreset(.blue)
        try check(!audio.running && audio.loaded == .brown, "Changing controls while paused must not start or decode audio")
        app.setEnabled(true)
        try check(audio.loaded == .blue && audio.volume == 0.25 && audio.lubed && app.status == .playing, "Resume applies paused preferences")
        let startsAtToggle = audio.starts
        app.setLubed(false)
        try check(!audio.lubed && audio.running && audio.starts == startsAtToggle, "Lube toggle must not restart or pause playback")
        let stopsBefore = keyboard.stops
        app.setPreset(.blue)
        try check(keyboard.stops == stopsBefore, "Selecting the current preset must not interrupt typing")
        audio.failStart = true
        audio.outputChanged()
        try check(app.status.recoveryMessage != nil && !keyboard.running && !audio.running, "Output failure stops listener and presents recovery")
        audio.failStart = false
        app.refresh()
        try check(app.status == .playing, "Retry recovers after a transient engine failure")
        audio.failLoad = true
        app.setPreset(.red)
        try check(app.status.recoveryMessage != nil && !keyboard.running, "Missing pack cannot report Playing")
        audio.failLoad = false
        app.refresh()
        try check(app.status == .playing && audio.loaded == .red, "Retry recovers after a load failure")
        keyboard.canStart = false
        keyboard.onDisabled?()
        try check(app.status == .listenerUnavailable && !audio.running, "Disabled/failed listener must not report Playing")
        keyboard.canStart = true
        app.refresh()
        try check(app.status == .playing, "Tap retry recovers")
        permission.granted = false
        app.refresh()
        try check(!app.hasKeyboardAccess && app.status == .needsPermission && !audio.running && !keyboard.running, "Revocation stops both services")
        permission.granted = true
        app.setSleeping(true)
        audio.outputChanged()
        try check(app.status == .sleeping && !audio.running && !keyboard.running, "Sleep blocks device-change restart")
        app.setSleeping(false)
        try check(app.status == .playing && audio.running, "Wake resumes when allowed")
    }

    static func login() throws {
        let service = FakeLogin()
        let login = LoginItemManager(service: service)
        login.setEnabled(true)
        try check(login.isRegistered && login.status == .requiresApproval, "Pending login approval must be visible")
        service.status = .enabled
        login.refresh()
        try check(login.status == .enabled, "External approval refresh")
        login.setEnabled(false)
        try check(!login.isRegistered, "Pending/enabled registration can be removed")
        service.failRegistration = true
        login.setEnabled(true)
        try check(!login.isRegistered && login.errorMessage != nil, "Registration error is surfaced with actual system state")
    }

    static func soundPacks() throws {
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/MechanicalKeyboard/Resources")
        for preset in SoundPreset.allCases {
            let pack = try SoundPack.load(preset, from: resources)
            try check(pack[.normal]?.count == 6, "All six variations load")
            for kind in SoundKind.allCases {
                try check(pack[kind]?.isEmpty == false, "Every sound category must be present")
            }
            let bank = try KeySoundBank.make(from: pack)
            var distinctKeys = Set<Data>()
            for code: Int64 in 0...127 {
                if KeySoundRouter.kind(for: code, isRepeat: false) == nil {
                    try check(bank[code] == nil, "Silent keys must not get an audible voice")
                    continue
                }
                guard let variants = bank[code] else { throw Failure(description: "Key \(code) has no sound") }
                try check(variants.count == 3, "Every key has subtle repeat variations")
                var distinctVariations = Set<Data>()
                for buffer in variants {
                    let frames = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
                    try check(frames.allSatisfy { $0.isFinite && abs($0) <= 0.281 }, "Tuned key samples must stay finite with headroom")
                    try check(frames.first == 0 && frames.last == 0, "Tuned key samples must retain clean edges")
                    distinctVariations.insert(Data(bytes: buffer.floatChannelData![0], count: frames.count * MemoryLayout<Float>.size))
                }
                try check(distinctVariations.count == 3, "Repeat variations must actually differ")
                let reference = variants[1]
                let signature = Data(bytes: reference.floatChannelData![0], count: Int(reference.frameLength) * MemoryLayout<Float>.size)
                try check(distinctKeys.insert(signature).inserted, "Every physical key must have a distinct base sound")
            }
            print("\(preset.rawValue): \(distinctKeys.count) distinct keys, three variations per key")
        }
        // A partially valid pack must fail completely, rather than silently losing variations.
        let temporary = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: temporary, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try FileManager.default.copyItem(at: resources.appendingPathComponent("Sounds"), to: temporary.appendingPathComponent("Sounds"))
        try FileManager.default.removeItem(at: temporary.appendingPathComponent("Sounds/Blue/normal-06.wav"))
        do {
            _ = try SoundPack.load(.blue, from: temporary)
            throw Failure(description: "Incomplete pack was accepted")
        } catch SoundError.missingSample { checks += 1 }
    }

    static func audioRendering() throws {
        let engine = AVAudioEngine()
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/MechanicalKeyboard/Resources")
        let sound = SoundEngine(engine: engine, resources: resources, variationSelector: { _, _ in 1 })
        try engine.enableManualRenderingMode(.offline, format: SoundPack.format, maximumFrameCount: 1024)
        let rendered = AVAudioPCMBuffer(pcmFormat: SoundPack.format, frameCapacity: 1024)!
        for preset in SoundPreset.allCases {
            try sound.load(preset)
            try sound.start(volume: 1)
            // Identical simultaneous transients expose summed clipping reliably.
            for _ in 0..<32 { sound.play(keyCode: 49) }
            var peak: Float = 0
            var firstAudible: Int?
            for block in 0..<12 {
                let result = try engine.renderOffline(1024, to: rendered)
                try check(result == .success, "Offline audio rendering must succeed")
                let samples = UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength))
                try check(samples.allSatisfy(\.isFinite), "Audio output must remain finite")
                if firstAudible == nil, let first = samples.firstIndex(where: { abs($0) > 0.0001 }) {
                    firstAudible = block * 1024 + first
                }
                peak = max(peak, samples.map(abs).max() ?? 0)
            }
            print("Rendered onset \(preset.rawValue): \(Double(firstAudible ?? -1) / 48) ms")
            try check(peak > 0.01 && peak <= 1, "Thirty-two overlapping voices must play without clipping")
            sound.stop()
            try check(!engine.isRunning, "Pause stops the actual audio engine")
            try sound.start(volume: 0)
            sound.play(keyCode: 0)
            for _ in 0..<4 {
                _ = try engine.renderOffline(1024, to: rendered)
                let samples = UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength))
                try check(samples.allSatisfy { abs($0) < 0.0001 }, "Muted restart must not replay old voices")
            }
            sound.stop()

            // A rapid run must equal the sum of independent strikes. This catches
            // queued playback, interrupted tails, and bad reuse after all 32 voices.
            // Use identical special-key samples to keep the reference deterministic.
            try sound.start(volume: 0.6)
            sound.play(keyCode: 49)
            var single: [Float] = []
            for _ in 0..<8 {
                let result = try engine.renderOffline(960, to: rendered)
                try check(result == .success, "Reference strike must render")
                single.append(contentsOf: UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength)))
            }
            sound.stop()
            // All 32 calls must reach the render engine before yielding to a queue.
            // Scaling the chord makes its waveform equal one reference strike and
            // keeps the limiter inactive, exposing missing or delayed voices.
            try sound.start(volume: 0.6 / 32)
            for _ in 0..<32 { sound.play(keyCode: 49) }
            var chord: [Float] = []
            for _ in 0..<8 {
                let result = try engine.renderOffline(960, to: rendered)
                try check(result == .success, "Immediate chord must render")
                chord.append(contentsOf: UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength)))
            }
            let chordError = zip(chord, single).map { abs($0 - $1) }.max() ?? 0
            try check(chordError < 0.001, "All 32 voices must start immediately without a playback queue: \(chordError)")
            sound.stop()
            try sound.start(volume: 0.6)
            var burst: [Float] = []
            for block in 0..<48 {
                if block < 40 { sound.play(keyCode: 49) }
                let result = try engine.renderOffline(960, to: rendered)
                try check(result == .success, "Rapid typing must render")
                burst.append(contentsOf: UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength)))
            }
            var expected = [Float](repeating: 0, count: burst.count)
            for hit in 0..<40 {
                for (frame, value) in single.enumerated() { expected[hit * 960 + frame] += value }
            }
            let difference = zip(burst, expected).map { abs($0 - $1) }.max() ?? 0
            try check(burst.allSatisfy { $0.isFinite && abs($0) < 1 }, "Rapid typing must stay finite and unclipped")
            try check(difference < 0.001, "Rapid strikes must overlap independently without cutting tails: \(difference)")
            print("Immediate chord \(preset.rawValue): 32 voices; maximum error \(chordError)")
            print("Independent overlap \(preset.rawValue): 40 strikes, 20 ms apart; maximum error \(difference)")
            sound.stop()

            sound.setLubed(true)
            try sound.start(volume: 0.6)
            sound.play(keyCode: 49)
            var lubed: [Float] = []
            for _ in 0..<8 {
                let result = try engine.renderOffline(960, to: rendered)
                try check(result == .success, "Lube effect must render")
                lubed.append(contentsOf: UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength)))
            }
            func spectralBalance(_ samples: [Float]) -> Double {
                func energy(_ frequencies: [Double]) -> Double {
                    frequencies.reduce(0) { total, frequency in
                        var real = 0.0, imaginary = 0.0
                        for (frame, value) in samples.enumerated() {
                            let angle = 2 * Double.pi * frequency * Double(frame) / 48_000
                            real += Double(value) * cos(angle)
                            imaginary += Double(value) * sin(angle)
                        }
                        return total + real * real + imaginary * imaginary
                    }
                }
                return energy([120, 180, 250, 350, 500]) / max(1e-12, energy([2500, 3500, 5000, 7000, 10000]))
            }
            try check(lubed.allSatisfy { $0.isFinite && abs($0) < 1 }, "Lube effect must not clip or produce invalid audio")
            try check(spectralBalance(lubed) > spectralBalance(single) * 2, "Lube must measurably emphasize body over sharp clicks")
            for _ in 0..<32 { sound.play(keyCode: 49) }
            for _ in 0..<12 {
                let result = try engine.renderOffline(1024, to: rendered)
                try check(result == .success, "Lubed chord must render")
                let samples = UnsafeBufferPointer(start: rendered.floatChannelData![0], count: Int(rendered.frameLength))
                try check(samples.allSatisfy { $0.isFinite && abs($0) <= 1 }, "Lube must retain clipping protection for full chords")
            }
            sound.setLubed(false)
            try check(engine.isRunning, "Toggling Lube must keep the engine running")
            sound.stop()

            // The user's multi-key case: eight DIFFERENT keys must remain eight
            // independent sounds, not switch to a shared chord/group recording.
            let keys: [Int64] = [0, 1, 2, 3, 4, 5, 38, 40]
            var mixedReference = [Float](repeating: 0, count: 7680)
            for key in keys {
                try sound.start(volume: 0.3)
                sound.play(keyCode: key)
                for block in 0..<8 {
                    let result = try engine.renderOffline(960, to: rendered)
                    try check(result == .success, "Individual chord key must render")
                    for frame in 0..<960 { mixedReference[block * 960 + frame] += rendered.floatChannelData![0][frame] }
                }
                sound.stop()
            }
            try sound.start(volume: 0.3)
            keys.forEach { sound.play(keyCode: $0) }
            var mixedError: Float = 0
            for block in 0..<8 {
                let result = try engine.renderOffline(960, to: rendered)
                try check(result == .success, "Mixed-key chord must render")
                for frame in 0..<960 {
                    mixedError = max(mixedError, abs(rendered.floatChannelData![0][frame] - mixedReference[block * 960 + frame]))
                }
            }
            try check(mixedError < 0.001, "Eight keys must equal their eight separate sounds: \(mixedError)")
            print("Mixed-key chord \(preset.rawValue): eight independent keys; maximum error \(mixedError)")
            sound.stop()
        }
    }

    static func lubeLoudness() throws {
        let engine = AVAudioEngine()
        let resources = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
            .appendingPathComponent("Sources/MechanicalKeyboard/Resources")
        let sound = SoundEngine(engine: engine, resources: resources, variationSelector: { _, _ in 1 })
        try engine.enableManualRenderingMode(.offline, format: SoundPack.format, maximumFrameCount: 960)
        let buffer = AVAudioPCMBuffer(pcmFormat: SoundPack.format, frameCapacity: 960)!
        // Exercise all six normal source timbres and the three special key sounds.
        let keys: [Int64] = [5, 0, 1, 2, 3, 4, 49, 36, 51]
        for preset in SoundPreset.allCases {
            try sound.load(preset)
            var energy: [Double] = []
            for enabled in [false, true, false] {
                sound.setLubed(enabled)
                var total = 0.0
                for key in keys {
                    try sound.start(volume: 0.6)
                    sound.play(keyCode: key)
                    var keyEnergy = 0.0
                    for _ in 0..<8 {
                        let status = try engine.renderOffline(960, to: buffer)
                        try check(status == .success, "Loudness comparison must render")
                        let frames = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
                        try check(frames.allSatisfy { $0.isFinite && abs($0) < 1 }, "Loudness compensation must remain unclipped")
                        keyEnergy += frames.reduce(0) { $0 + Double($1) * Double($1) }
                    }
                    // Normal typing keys occur more often than the special keys.
                    total += keyEnergy * (key < 6 ? 4 : 1)
                    sound.stop()
                }
                energy.append(total)
            }
            let change = 10 * log10(energy[1] / energy[0])
            print("Lube level \(preset.rawValue): \(change) dB relative to normal")
            try check(abs(change) < 1.5, "Lube should retain normal typing loudness: \(change) dB")
            try check(abs(10 * log10(energy[2] / energy[0])) < 0.01, "Lube Off must restore the original level")
            sound.setLubed(true)
            try sound.start(volume: 0)
            sound.play(keyCode: 0)
            for _ in 0..<8 {
                let status = try engine.renderOffline(960, to: buffer)
                try check(status == .success, "Muted Lube must render")
                let frames = UnsafeBufferPointer(start: buffer.floatChannelData![0], count: Int(buffer.frameLength))
                try check(frames.allSatisfy { abs($0) < 0.0001 }, "Makeup gain must not defeat mute")
            }
            sound.stop()
        }
    }

    static func writePreviews() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        let destination = root.appendingPathComponent("dist/AudioPreviews")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let engine = AVAudioEngine()
        let sound = SoundEngine(engine: engine, resources: root.appendingPathComponent("Sources/MechanicalKeyboard/Resources"))
        try engine.enableManualRenderingMode(.offline, format: SoundPack.format, maximumFrameCount: 128)
        let buffer = AVAudioPCMBuffer(pcmFormat: SoundPack.format, frameCapacity: 128)!
        var events: [(frame: Int, key: Int64)] = []
        for (index, key) in [Int64(0), 0, 1, 1, 2, 2, 3, 3, 49, 36, 51].enumerated() {
            events.append((Int((0.15 + Double(index) * 0.23) * 48_000), key))
        }
        let keys: [Int64] = [0, 1, 2, 3, 5, 4, 38, 40, 37, 49, 12, 13, 14, 15, 17, 16]
        for index in 0..<36 { events.append((Int((2.8 + Double(index) * 0.075) * 48_000), keys[index % keys.count])) }
        for (time, chord) in [(5.8, Array(keys.prefix(2))), (6.1, Array(keys.prefix(4))), (6.5, Array(keys.prefix(8)))] {
            for key in chord { events.append((Int(time * 48_000), key)) }
        }
        events.sort { $0.frame < $1.frame }
        for preset in SoundPreset.allCases {
            try sound.load(preset)
            for lubed in [false, true] {
                sound.setLubed(lubed)
                try sound.start(volume: 0.65)
                let file = try AVAudioFile(forWriting: destination.appendingPathComponent("\(preset.rawValue)-Lube\(lubed ? "On" : "Off").wav"), settings: [
                    AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: 48_000,
                    AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 16,
                    AVLinearPCMIsFloatKey: false, AVLinearPCMIsBigEndianKey: false
                ])
                var event = 0
                for frame in stride(from: 0, to: 48_000 * 7, by: 128) {
                    while event < events.count && events[event].frame <= frame {
                        sound.play(keyCode: events[event].key)
                        event += 1
                    }
                    let result = try engine.renderOffline(128, to: buffer)
                    try check(result == .success, "Preview must render")
                    try file.write(from: buffer)
                }
                sound.stop()
            }
        }
        print("Wrote six seven-second per-key/Lube previews using the actual playback engine.")
    }
}

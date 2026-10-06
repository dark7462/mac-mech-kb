import AVFoundation
import AudioToolbox
import Foundation

@MainActor
protocol SoundPlaying: AnyObject {
    var onConfigurationChange: (() -> Void)? { get set }
    func load(_ preset: SoundPreset) throws
    func start(volume: Double) throws
    func setVolume(_ volume: Double)
    func setLubed(_ enabled: Bool)
    func play(keyCode: Int64)
    func stop()
}

@MainActor
final class SoundEngine: SoundPlaying {
    private let engine: AVAudioEngine
    private let resources: URL?
    private let mixer = AVAudioMixerNode()
    private let lubeEQ = AVAudioUnitEQ(numberOfBands: 3)
    private let limiter = AVAudioUnitEffect(audioComponentDescription: AudioComponentDescription(
        componentType: kAudioUnitType_Effect,
        componentSubType: kAudioUnitSubType_PeakLimiter,
        componentManufacturer: kAudioUnitManufacturer_Apple,
        componentFlags: 0, componentFlagsMask: 0
    ))
    private var voices: [AVAudioPlayerNode] = []
    private var buffers: [Int64: [AVAudioPCMBuffer]] = [:]
    private var loadedPreset: SoundPreset?
    private var nextVoice = 0
    private var variations = Array(repeating: SampleVariationPicker(), count: 128)
    private var random = SystemRandomNumberGenerator()
    private let variationSelector: ((Int64, Int) -> Int)?
    private var observer: NSObjectProtocol?
    var onConfigurationChange: (() -> Void)?

    init(engine: AVAudioEngine = AVAudioEngine(), resources: URL? = Bundle.module.resourceURL,
         variationSelector: ((Int64, Int) -> Int)? = nil) {
        self.engine = engine
        self.resources = resources
        self.variationSelector = variationSelector
        engine.attach(mixer)
        engine.attach(lubeEQ)
        engine.attach(limiter)
        // A digital lube effect: stronger body, less upper click and scratch.
        lubeEQ.bands[0].filterType = .lowShelf
        lubeEQ.bands[0].frequency = 350
        lubeEQ.bands[0].gain = 4
        lubeEQ.bands[1].filterType = .highShelf
        lubeEQ.bands[1].frequency = 1_600
        lubeEQ.bands[1].gain = -8
        lubeEQ.bands[2].filterType = .lowPass
        lubeEQ.bands[2].frequency = 5_500
        lubeEQ.bands.forEach { $0.bypass = false }
        lubeEQ.bypass = true
        // Bound the mixed peak during large chords without turning down individual hits.
        limiter.auAudioUnit.parameterTree?
            .parameter(withAddress: AUParameterAddress(kLimiterParam_AttackTime))?.value = 0.001
        engine.connect(mixer, to: lubeEQ, format: SoundPack.format)
        engine.connect(lubeEQ, to: limiter, format: SoundPack.format)
        engine.connect(limiter, to: engine.mainMixerNode, format: SoundPack.format)
        // Allocate every player before listening, never in the key-event callback.
        for _ in 0..<32 {
            let voice = AVAudioPlayerNode()
            engine.attach(voice)
            engine.connect(voice, to: mixer, format: SoundPack.format)
            voices.append(voice)
        }
        observer = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil
        ) { [weak self] _ in
            // Never touch or destroy the engine on its internal notification thread.
            DispatchQueue.main.async {
                guard let self else { return }
                self.stop()
                // The controller decides whether restarting is currently allowed.
                self.onConfigurationChange?()
            }
        }
    }

    func load(_ preset: SoundPreset) throws {
        guard preset != loadedPreset else { return }
        stop()
        loadedPreset = nil
        buffers.removeAll()
        guard let resources else {
            throw SoundError.missingSample("Sounds")
        }
        buffers = try KeySoundBank.make(from: SoundPack.load(preset, from: resources))
        loadedPreset = preset
        setLubed(!lubeEQ.bypass)
        variations = Array(repeating: SampleVariationPicker(), count: 128)
    }

    func start(volume: Double) throws {
        guard loadedPreset != nil else { throw SoundError.noPreset }
        setVolume(volume)
        if !engine.isRunning {
            engine.prepare()
            try engine.start()
        }
    }

    func setVolume(_ volume: Double) {
        mixer.outputVolume = Float(volume.isFinite ? min(1, max(0, volume)) : 0)
    }

    func setLubed(_ enabled: Bool) {
        // Match the normal level without changing the lube filters. Blue loses
        // more energy when its bright click is softened than Brown or Red do.
        let makeupGain: Float
        switch loadedPreset {
        case .blue: makeupGain = 9.5
        case .brown: makeupGain = 3.25
        case .red: makeupGain = 4
        case nil: makeupGain = 0
        }
        let gain: Float = enabled ? makeupGain : 0
        if lubeEQ.globalGain != gain { lubeEQ.globalGain = gain }
        if lubeEQ.bypass != !enabled { lubeEQ.bypass = !enabled }
    }

    func play(keyCode: Int64) {
        guard engine.isRunning, let options = buffers[keyCode], !options.isEmpty else { return }
        let index = variationSelector?(keyCode, options.count)
            ?? variations[Int(keyCode)].nextIndex(count: options.count, using: &random) ?? 0
        guard options.indices.contains(index) else { return }
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        // Each call starts a separate voice immediately and returns. No sounds are
        // appended behind a playing buffer. At capacity, replace the oldest voice.
        if voice.isPlaying { voice.stop() }
        voice.scheduleBuffer(options[index], at: nil, options: .interrupts, completionHandler: nil)
        voice.play()
    }

    func stop() {
        mixer.outputVolume = 0
        voices.forEach { $0.stop() }
        if engine.isRunning { engine.stop() }
        nextVoice = 0
    }

    deinit {
        if let observer { NotificationCenter.default.removeObserver(observer) }
        engine.stop()
    }
}

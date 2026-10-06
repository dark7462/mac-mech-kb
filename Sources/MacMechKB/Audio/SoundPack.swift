import AVFoundation

// One format for every file and player connection; the main mixer handles device conversion.
enum SoundPack {
    static let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1)!

    static func load(_ preset: SoundPreset, from resources: URL) throws -> [SoundKind: [AVAudioPCMBuffer]] {
        var loaded: [SoundKind: [AVAudioPCMBuffer]] = [:]
        for kind in SoundKind.allCases {
            let names = kind == .normal
                ? (1...6).map { String(format: "normal-%02d", $0) }
                : [kind.rawValue]
            loaded[kind] = try names.map { name in
                let label = "\(preset.rawValue)/\(name).wav"
                let url = resources.appendingPathComponent("Sounds").appendingPathComponent(label)
                guard FileManager.default.fileExists(atPath: url.path) else {
                    throw SoundError.missingSample(label)
                }
                let file = try AVAudioFile(forReading: url)
                guard file.processingFormat == format,
                      file.length > 0, file.length <= 9_600,
                      let buffer = AVAudioPCMBuffer(
                        pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)
                      ) else { throw SoundError.invalidSample(label) }
                try file.read(into: buffer)
                guard buffer.frameLength == AVAudioFrameCount(file.length) else {
                    throw SoundError.invalidSample(label)
                }
                return buffer
            }
        }
        return loaded
    }
}

enum SoundError: LocalizedError {
    case missingSample(String)
    case invalidSample(String)
    case noPreset

    var errorDescription: String? {
        switch self {
        case .missingSample(let name): return "A sound file is missing: \(name). Rebuild the app."
        case .invalidSample(let name): return "A sound file is invalid: \(name). Rebuild the app."
        case .noPreset: return "No sound preset is loaded. Try choosing a preset again."
        }
    }
}

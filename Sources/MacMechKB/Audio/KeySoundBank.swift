import AVFoundation

/// Prepares a distinct voice for every supported physical key before listening.
/// These are tuned derivatives of the recordings, not recordings of every key.
enum KeySoundBank {
    static func make(from pack: [SoundKind: [AVAudioPCMBuffer]]) throws -> [Int64: [AVAudioPCMBuffer]] {
        var result: [Int64: [AVAudioPCMBuffer]] = [:]
        for keyCode: Int64 in 0...127 {
            guard let kind = KeySoundRouter.kind(for: keyCode, isRepeat: false),
                  let samples = pack[kind], !samples.isEmpty else { continue }
            let source = samples[Int((keyCode * 37 + 13) % Int64(samples.count))]
            // A fixed permutation gives each key a stable tone without pitch rows
            // sounding like a musical scale. Repeated hits vary by only five cents.
            let cents = Double((keyCode * 53) % 127) / 126 * 160 - 80
            result[keyCode] = try [-5.0, 0, 5.0].enumerated().map { variation, offset in
                try tune(source, cents: cents + offset, gain: [0.97, 1, 1.03][variation])
            }
        }
        return result
    }

    private static func tune(_ source: AVAudioPCMBuffer, cents: Double, gain: Float) throws -> AVAudioPCMBuffer {
        let rate = 48_000 / pow(2, cents / 1200)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1),
              let converter = AVAudioConverter(from: source.format, to: format),
              let converted = AVAudioPCMBuffer(pcmFormat: format,
                frameCapacity: AVAudioFrameCount(ceil(Double(source.frameLength) * rate / 48_000)) + 64)
        else { throw SoundError.invalidSample("key tuning") }
        converter.sampleRateConverterQuality = 127
        converter.primeMethod = .normal
        var supplied = false
        var error: NSError?
        let status = converter.convert(to: converted, error: &error) { _, status in
            guard !supplied else { status.pointee = .endOfStream; return nil }
            supplied = true
            status.pointee = .haveData
            return source
        }
        if let error { throw error }
        guard status != .error, converted.frameLength > 0,
              let output = AVAudioPCMBuffer(pcmFormat: SoundPack.format, frameCapacity: converted.frameLength)
        else { throw SoundError.invalidSample("key tuning") }
        // Reinterpret the resampled frames at 48 kHz for the desired pitch.
        // All conversion and allocation happen here, never on a keystroke.
        output.frameLength = converted.frameLength
        let input = converted.floatChannelData![0]
        let target = output.floatChannelData![0]
        let count = Int(output.frameLength)
        var peak: Float = 0
        for i in 0..<count {
            let fade = min(1, Float(i) / 12, Float(count - 1 - i) / 96)
            target[i] = input[i] * fade
            peak = max(peak, abs(target[i]))
        }
        guard peak.isFinite, peak > 0 else { throw SoundError.invalidSample("key tuning") }
        let level = min(gain, 0.28 / peak)
        for i in 0..<count { target[i] *= level }
        return output
    }
}

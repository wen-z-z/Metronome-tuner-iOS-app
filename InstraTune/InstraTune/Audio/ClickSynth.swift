import Foundation
import AVFoundation

/// Renders short metronome ticks into mono float sample buffers.
enum ClickSynth {

    static func render(_ p: ClickParameters, sampleRate: Double, gain: Float = 1) -> [Float] {
        let n = max(8, Int(p.duration * sampleRate))
        var out = [Float](repeating: 0, count: n)

        let softness = min(max(p.softness, 0), 1)
        // Soft sounds get a longer attack; sharp sounds hit instantly.
        let attack = max(1, Int((0.0004 + 0.015 * softness) * sampleRate))
        // Sharp sounds decay fast; soft sounds ring a little.
        let decayRate = 3.0 + 9.0 * (1.0 - softness)

        var phase = 0.0
        let increment = 2 * Double.pi * p.pitch / sampleRate
        var rng: UInt32 = 0x2545F491   // deterministic noise
        var noiseState = 0.0
        // One-pole low-pass for noise, cutoff = pitch.
        let noiseCoefficient = min(0.999, 1 - exp(-2 * Double.pi * p.pitch / sampleRate))

        for i in 0..<n {
            let envelope: Double
            if i < attack {
                envelope = Double(i) / Double(attack)
            } else {
                let d = Double(i - attack) / Double(max(1, n - attack))
                envelope = exp(-decayRate * d) * (1 - d)
            }

            var sample: Double
            switch p.waveform {
            case .sine:
                sample = sin(phase)
            case .triangle:
                sample = (2 / Double.pi) * asin(sin(phase))
            case .square:
                // Blend square toward sine as softness increases.
                let square: Double = sin(phase) >= 0 ? 1 : -1
                sample = square * (1 - softness) + sin(phase) * softness
            case .noise:
                rng = rng &* 1664525 &+ 1013904223
                let white = Double(rng) / Double(UInt32.max) * 2 - 1
                noiseState += noiseCoefficient * (white - noiseState)
                sample = noiseState * 2.5
            }
            phase += increment
            if phase > 2 * Double.pi { phase -= 2 * Double.pi }

            out[i] = Float(sample * envelope)
        }

        // Soften the high end on top of the waveform choice.
        if softness > 0 {
            let a = Float(1 - 0.85 * softness)
            var y: Float = 0
            for i in 0..<n {
                y += a * (out[i] - y)
                out[i] = y
            }
        }

        // Normalise so every preset lands at a similar loudness.
        let peak = out.reduce(0) { max($0, abs($1)) }
        if peak > 0 {
            let scale = 0.9 / peak * gain
            for i in 0..<n { out[i] *= scale }
        }
        return out
    }
}

/// Loads an audio file (MP3, WAV, AIFF, M4A…) into a mono float buffer at the
/// requested sample rate.
enum AudioFileLoader {
    enum LoadError: LocalizedError {
        case bufferAllocation, conversion
        var errorDescription: String? {
            switch self {
            case .bufferAllocation: return "Could not allocate an audio buffer."
            case .conversion: return "Could not convert the audio file."
            }
        }
    }

    static func loadMono(url: URL, sampleRate: Double, maxSeconds: Double) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let sourceFormat = file.processingFormat
        let frameCount = AVAudioFrameCount(min(Double(file.length), maxSeconds * sourceFormat.sampleRate))
        guard frameCount > 0,
              let input = AVAudioPCMBuffer(pcmFormat: sourceFormat, frameCapacity: frameCount) else {
            throw LoadError.bufferAllocation
        }
        try file.read(into: input, frameCount: frameCount)

        guard let outputFormat = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let converter = AVAudioConverter(from: sourceFormat, to: outputFormat) else {
            throw LoadError.conversion
        }
        let capacity = AVAudioFrameCount(Double(input.frameLength) * sampleRate / sourceFormat.sampleRate) + 1024
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else {
            throw LoadError.bufferAllocation
        }

        var consumed = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if consumed {
                outStatus.pointee = .endOfStream
                return nil
            }
            consumed = true
            outStatus.pointee = .haveData
            return input
        }
        if status == .error {
            if let conversionError { throw conversionError }
            throw LoadError.conversion
        }

        let n = Int(output.frameLength)
        guard n > 0, let channel = output.floatChannelData?[0] else { throw LoadError.conversion }
        var samples = Array(UnsafeBufferPointer(start: channel, count: n))

        // Normalise and add a short fade-out so the tail never clicks.
        let peak = samples.reduce(0) { max($0, abs($1)) }
        if peak > 0 {
            let g = 0.9 / peak
            for i in 0..<n { samples[i] *= g }
        }
        let fade = min(n, Int(sampleRate * 0.01))
        for i in 0..<fade {
            samples[n - 1 - i] *= Float(i) / Float(fade)
        }
        return samples
    }

    /// Simple linear-interpolation resampler used to pitch a file up or down.
    static func resample(_ samples: [Float], rate: Double) -> [Float] {
        guard rate != 1, samples.count > 1 else { return samples }
        let outCount = max(1, Int(Double(samples.count) / rate))
        var out = [Float](repeating: 0, count: outCount)
        for i in 0..<outCount {
            let position = Double(i) * rate
            let index = Int(position)
            let fraction = Float(position - Double(index))
            let a = samples[min(index, samples.count - 1)]
            let b = samples[min(index + 1, samples.count - 1)]
            out[i] = a + (b - a) * fraction
        }
        return out
    }
}


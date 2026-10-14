import AVFoundation
import Combine

/// Plays a steady reference tone at an exact frequency for tuning by ear.
/// Frequency and level glide smoothly so starting, stopping and switching
/// notes never clicks.
final class TonePlayer: ObservableObject {

    @Published private(set) var activeNote: Note?
    @Published private(set) var activeFrequency: Double?

    var volume: Double = 0.35

    private let engine = AVAudioEngine()
    private var node: AVAudioSourceNode?
    private let sampleRate: Double = 44_100

    // Render-thread state. Plain doubles: aligned 64-bit reads/writes are
    // atomic on Apple silicon and the glide smooths any transient mismatch.
    private var phase = 0.0
    private var frequency = 440.0
    private var targetFrequency = 440.0
    private var amplitude = 0.0
    private var targetAmplitude = 0.0

    private var stopWorkItem: DispatchWorkItem?

    init() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1) else { return }
        let source = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let n = Int(frameCount)
            guard let self else {
                for i in 0..<n { out[i] = 0 }
                return noErr
            }
            self.render(into: out, frames: n)
            return noErr
        }
        engine.attach(source)
        engine.connect(source, to: engine.mainMixerNode, format: format)
        node = source
    }

    private func render(into out: UnsafeMutablePointer<Float>, frames n: Int) {
        let twoPi = 2 * Double.pi
        for i in 0..<n {
            amplitude += (targetAmplitude - amplitude) * 0.0015
            if amplitude < 1e-4 && targetAmplitude == 0 {
                frequency = targetFrequency
            } else {
                frequency += (targetFrequency - frequency) * 0.002
            }
            // A few harmonics make the tone warmer and easier to tune against.
            let sample = sin(phase) * 0.6
                + sin(2 * phase) * 0.25
                + sin(3 * phase) * 0.1
                + sin(4 * phase) * 0.05
            out[i] = Float(sample * amplitude)
            phase += twoPi * frequency / sampleRate
            if phase > twoPi { phase -= twoPi }
        }
    }

    // MARK: Control

    func play(note: Note, a4: Double) {
        play(frequency: note.frequency(a4: a4))
        activeNote = note
    }

    func play(frequency f: Double) {
        stopWorkItem?.cancel()
        AudioSession.configure(recording: false)
        if !engine.isRunning {
            do {
                engine.prepare()
                try engine.start()
            } catch {
                print("TonePlayer failed to start: \(error)")
                return
            }
        }
        if amplitude < 1e-4 { frequency = f }
        targetFrequency = f
        targetAmplitude = volume
        activeFrequency = f
        activeNote = nil
    }

    /// Fades the tone out, then releases the audio engine shortly afterwards.
    func stop() {
        targetAmplitude = 0
        activeNote = nil
        activeFrequency = nil
        stopWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.targetAmplitude == 0 else { return }
            self.engine.stop()
        }
        stopWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: item)
    }

    func toggle(note: Note, a4: Double) {
        if activeNote == note {
            stop()
        } else {
            play(note: note, a4: a4)
        }
    }
}

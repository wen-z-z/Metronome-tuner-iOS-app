import AVFoundation
import Combine
import os

/// Sample-accurate metronome built on an `AVAudioSourceNode`.
///
/// The render callback counts frames and drops a click buffer exactly on each
/// beat boundary, so timing never depends on timers or the main thread.
final class MetronomeEngine: ObservableObject {

    static let sampleRate: Double = 44_100
    static let bpmRange: ClosedRange<Double> = 20...300

    // MARK: Published state (main thread)

    @Published var bpm: Double = 120 {
        didSet { updateTiming(); save() }
    }
    @Published var timeSignature = TimeSignature(beats: 4, noteValue: 4) {
        didSet { updateTiming(); save() }
    }
    @Published var settings = MetronomeSettings() {
        didSet { rebuildBuffers(); save() }
    }
    @Published private(set) var isRunning = false
    /// 0-based index of the beat currently sounding, or -1 when stopped.
    @Published private(set) var currentBeat: Int = -1
    @Published var loadError: String?

    // MARK: Audio graph

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?

    private struct Voice {
        var samples: [Float]
        var position: Int
        var startOffset: Int
    }

    /// State shared with the render thread. Only touch while holding `lock`.
    private struct RenderState {
        var running = false
        var framesPerBeat = 22_050
        var framesUntilNextBeat = 0
        var beatIndex = 0
        var accents: [BeatAccent] = [.accent, .normal, .normal, .normal]
        var normal: [Float] = []
        var accent: [Float] = []
        var voices: [Voice] = []
    }

    private var rt = RenderState()
    private let lock: UnsafeMutablePointer<os_unfair_lock> = {
        let pointer = UnsafeMutablePointer<os_unfair_lock>.allocate(capacity: 1)
        pointer.initialize(to: os_unfair_lock())
        return pointer
    }()

    private var tapTimes: [Date] = []
    private var isLoaded = false
    private var observers: [NSObjectProtocol] = []

    // MARK: Init

    init() {
        if let saved = Self.loadSaved() {
            bpm = saved.bpm
            timeSignature = saved.timeSignature
            settings = saved.settings
        }
        isLoaded = true
        rt.voices.reserveCapacity(16)
        buildGraph()
        updateTiming()
        rebuildBuffers()

        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                            object: nil, queue: .main) { [weak self] _ in
            self?.stop()
        })
    }

    deinit {
        observers.forEach { NotificationCenter.default.removeObserver($0) }
        lock.deinitialize(count: 1)
        lock.deallocate()
    }

    private func buildGraph() {
        guard let format = AVAudioFormat(standardFormatWithSampleRate: Self.sampleRate, channels: 1) else { return }
        let node = AVAudioSourceNode(format: format) { [weak self] _, _, frameCount, audioBufferList -> OSStatus in
            let buffers = UnsafeMutableAudioBufferListPointer(audioBufferList)
            guard let out = buffers[0].mData?.assumingMemoryBound(to: Float.self) else { return noErr }
            let n = Int(frameCount)
            for i in 0..<n { out[i] = 0 }
            self?.render(into: out, frames: n)
            return noErr
        }
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 1
        sourceNode = node
    }

    // MARK: Render thread

    private func render(into out: UnsafeMutablePointer<Float>, frames n: Int) {
        os_unfair_lock_lock(lock)
        defer { os_unfair_lock_unlock(lock) }

        if rt.running {
            var i = 0
            while i < n {
                if rt.framesUntilNextBeat <= 0 {
                    let index = rt.beatIndex
                    let count = max(1, rt.accents.count)
                    let kind: BeatAccent = rt.accents.isEmpty ? .normal : rt.accents[index % count]
                    switch kind {
                    case .accent:
                        rt.voices.append(Voice(samples: rt.accent, position: 0, startOffset: i))
                    case .normal:
                        rt.voices.append(Voice(samples: rt.normal, position: 0, startOffset: i))
                    case .silent:
                        break
                    }
                    DispatchQueue.main.async { [weak self] in self?.currentBeat = index }
                    rt.beatIndex = (index + 1) % count
                    rt.framesUntilNextBeat = rt.framesPerBeat
                }
                let step = min(rt.framesUntilNextBeat, n - i)
                i += step
                rt.framesUntilNextBeat -= step
            }
        }

        // Mix every active click (including previews) into the output.
        var k = 0
        while k < rt.voices.count {
            var voice = rt.voices[k]
            var frame = voice.startOffset
            while frame < n && voice.position < voice.samples.count {
                out[frame] += voice.samples[voice.position]
                frame += 1
                voice.position += 1
            }
            voice.startOffset = 0
            if voice.position >= voice.samples.count {
                rt.voices.remove(at: k)
            } else {
                rt.voices[k] = voice
                k += 1
            }
        }

        for i in 0..<n { out[i] = max(-1, min(1, out[i])) }
    }

    private func withLock(_ body: (inout RenderState) -> Void) {
        os_unfair_lock_lock(lock)
        body(&rt)
        os_unfair_lock_unlock(lock)
    }

    // MARK: Transport

    func start() {
        guard ensureEngineRunning() else { return }
        withLock { state in
            state.running = true
            state.beatIndex = 0
            state.framesUntilNextBeat = 0
            state.voices.removeAll()
        }
        isRunning = true
    }

    func stop() {
        withLock { state in
            state.running = false
            state.voices.removeAll()
        }
        isRunning = false
        currentBeat = -1
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    /// Averages recent taps to set the tempo.
    func tapTempo() {
        let now = Date()
        if let last = tapTimes.last, now.timeIntervalSince(last) > 2 {
            tapTimes.removeAll()
        }
        tapTimes.append(now)
        if tapTimes.count > 6 { tapTimes.removeFirst() }
        guard tapTimes.count >= 2 else { return }
        var intervals: [TimeInterval] = []
        for i in 1..<tapTimes.count {
            intervals.append(tapTimes[i].timeIntervalSince(tapTimes[i - 1]))
        }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        let newBpm = (60 / average).rounded()
        bpm = min(max(newBpm, Self.bpmRange.lowerBound), Self.bpmRange.upperBound)
    }

    enum PreviewTarget { case beat, accent }

    /// Plays one click so the user can audition the current sound settings.
    func preview(_ target: PreviewTarget) {
        guard ensureEngineRunning() else { return }
        withLock { state in
            let samples = target == .beat ? state.normal : state.accent
            state.voices.append(Voice(samples: samples, position: 0, startOffset: 0))
        }
    }

    @discardableResult
    private func ensureEngineRunning() -> Bool {
        AudioSession.configure(recording: false)
        guard !engine.isRunning else { return true }
        do {
            engine.prepare()
            try engine.start()
            return true
        } catch {
            loadError = "Audio engine failed to start: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: Timing & sounds

    private func updateTiming() {
        // BPM counts the note value in the denominator (e.g. eighths in 6/8).
        let framesPerBeat = max(1, Int(Self.sampleRate * 60 / max(bpm, 1)))
        let accents = timeSignature.accents
        withLock { state in
            state.framesPerBeat = framesPerBeat
            state.accents = accents
            if state.framesUntilNextBeat > framesPerBeat {
                state.framesUntilNextBeat = framesPerBeat
            }
            state.beatIndex %= max(1, accents.count)
        }
    }

    private func rebuildBuffers() {
        loadError = nil
        let normal = renderSamples(for: settings.beat, gain: 0.7, rate: 1)
        let accent: [Float]
        if let accentSource = settings.accent {
            accent = renderSamples(for: accentSource, gain: 1, rate: 1)
        } else {
            // Derived accent: louder and a little higher than the beat.
            switch settings.beat {
            case .synth(var params):
                params.pitch = min(params.pitch * 1.5, 6000)
                accent = ClickSynth.render(params, sampleRate: Self.sampleRate, gain: 1)
            case .file:
                accent = renderSamples(for: settings.beat, gain: 1, rate: 1.2)
            }
        }
        withLock { state in
            state.normal = normal
            state.accent = accent
        }
    }

    private func renderSamples(for source: SoundSource, gain: Float, rate: Double) -> [Float] {
        switch source {
        case .synth(let params):
            return ClickSynth.render(params, sampleRate: Self.sampleRate, gain: gain)
        case .file(let name):
            do {
                var samples = try AudioFileLoader.loadMono(url: SoundLibrary.url(for: name),
                                                           sampleRate: Self.sampleRate,
                                                           maxSeconds: 3)
                samples = AudioFileLoader.resample(samples, rate: rate)
                return samples.map { $0 * gain }
            } catch {
                loadError = "Couldn't load \(SoundLibrary.displayName(name)); using the classic click instead."
                return ClickSynth.render(SoundPreset.classic.params, sampleRate: Self.sampleRate, gain: gain)
            }
        }
    }

    // MARK: Persistence

    private struct SavedState: Codable {
        var bpm: Double
        var timeSignature: TimeSignature
        var settings: MetronomeSettings
    }

    private static let defaultsKey = "metronome.state"

    private func save() {
        guard isLoaded else { return }
        let state = SavedState(bpm: bpm, timeSignature: timeSignature, settings: settings)
        if let data = try? JSONEncoder().encode(state) {
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }
    }

    private static func loadSaved() -> SavedState? {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey) else { return nil }
        return try? JSONDecoder().decode(SavedState.self, from: data)
    }
}

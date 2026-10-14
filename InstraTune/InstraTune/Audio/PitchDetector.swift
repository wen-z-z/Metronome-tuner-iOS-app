import AVFoundation
import Accelerate
import Combine

/// Listens to the microphone and estimates the fundamental frequency of
/// whatever is being played, using the McLeod pitch method (normalised
/// square-difference / autocorrelation with key-maximum picking).
final class PitchDetector: ObservableObject {

    enum Permission { case undetermined, granted, denied }

    @Published private(set) var permission: Permission
    @Published private(set) var isListening = false
    /// Smoothed detected frequency in Hz, or nil when nothing clear is heard.
    @Published private(set) var frequency: Double?
    /// Input level 0…1 for a simple meter.
    @Published private(set) var inputLevel: Float = 0

    private let engine = AVAudioEngine()
    private var history: [Double] = []
    private var missCount = 0

    init() {
        permission = Self.currentPermission()
    }

    // MARK: Permission

    private static func currentPermission() -> Permission {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return .granted
        case .denied: return .denied
        default: return .undetermined
        }
    }

    func refreshPermission() {
        permission = Self.currentPermission()
    }

    func requestPermission(_ completion: @escaping (Bool) -> Void) {
        AVAudioApplication.requestRecordPermission { granted in
            DispatchQueue.main.async {
                self.permission = granted ? .granted : .denied
                completion(granted)
            }
        }
    }

    // MARK: Start / stop

    func start() {
        guard !isListening, permission == .granted else { return }
        AudioSession.configure(recording: true)

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.sampleRate > 0, format.channelCount > 0 else {
            print("PitchDetector: no usable input format")
            return
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4096, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }
        do {
            engine.prepare()
            try engine.start()
            isListening = true
        } catch {
            print("PitchDetector failed to start: \(error)")
            input.removeTap(onBus: 0)
        }
    }

    func stop() {
        guard isListening else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        isListening = false
        frequency = nil
        inputLevel = 0
        history.removeAll()
        AudioSession.configure(recording: false)
    }

    // MARK: Processing

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        let n = Int(buffer.frameLength)
        guard n >= 1024 else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: n))
        let sampleRate = buffer.format.sampleRate

        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))

        let detected: Double? = rms > 0.004 ? Self.detectPitch(samples, sampleRate: sampleRate) : nil

        DispatchQueue.main.async {
            self.inputLevel = min(1, rms * 10)
            self.update(with: detected)
        }
    }

    private func update(with detected: Double?) {
        guard let detected else {
            missCount += 1
            if missCount > 4 {
                frequency = nil
                history.removeAll()
            }
            return
        }
        missCount = 0
        history.append(detected)
        if history.count > 5 { history.removeFirst() }
        // Median filter removes the occasional octave glitch.
        frequency = history.sorted()[history.count / 2]
    }

    /// Returns the estimated fundamental in Hz, or nil if the signal isn't periodic enough.
    static func detectPitch(_ x: [Float], sampleRate: Double) -> Double? {
        let n = x.count
        let minLag = max(2, Int(sampleRate / 2500))      // up to ~2.5 kHz
        let maxLag = min(n / 2, Int(sampleRate / 28))    // down to ~28 Hz (below bass low E)
        guard maxLag > minLag + 2 else { return nil }

        // Prefix sums of x² let us compute the NSDF denominator in O(1) per lag.
        var squares = [Float](repeating: 0, count: n + 1)
        for i in 0..<n { squares[i + 1] = squares[i] + x[i] * x[i] }

        var nsdf = [Float](repeating: 0, count: maxLag + 1)
        x.withUnsafeBufferPointer { pointer in
            guard let base = pointer.baseAddress else { return }
            for lag in minLag...maxLag {
                var acf: Float = 0
                vDSP_dotpr(base, 1, base + lag, 1, &acf, vDSP_Length(n - lag))
                let m = squares[n - lag] + (squares[n] - squares[lag])
                nsdf[lag] = m > 0 ? 2 * acf / m : 0
            }
        }

        // Key-maximum picking: one peak per positive region after the first zero crossing.
        var peaks: [(lag: Int, value: Float)] = []
        var lag = minLag
        while lag <= maxLag && nsdf[lag] > 0 { lag += 1 }
        while lag <= maxLag {
            while lag <= maxLag && nsdf[lag] <= 0 { lag += 1 }
            var bestLag = -1
            var bestValue: Float = 0
            while lag <= maxLag && nsdf[lag] > 0 {
                if nsdf[lag] > bestValue {
                    bestValue = nsdf[lag]
                    bestLag = lag
                }
                lag += 1
            }
            if bestLag >= 0 { peaks.append((bestLag, bestValue)) }
        }

        guard let highest = peaks.map({ $0.value }).max(), highest > 0.55 else { return nil }
        let threshold = highest * 0.9
        guard let chosen = peaks.first(where: { $0.value >= threshold }) else { return nil }

        // Parabolic interpolation around the chosen peak for sub-sample accuracy.
        var refined = Double(chosen.lag)
        if chosen.lag > minLag && chosen.lag < maxLag {
            let a = Double(nsdf[chosen.lag - 1])
            let b = Double(nsdf[chosen.lag])
            let c = Double(nsdf[chosen.lag + 1])
            let denominator = a - 2 * b + c
            if abs(denominator) > 1e-9 {
                refined = Double(chosen.lag) + 0.5 * (a - c) / denominator
            }
        }
        guard refined > 0 else { return nil }
        return sampleRate / refined
    }
}

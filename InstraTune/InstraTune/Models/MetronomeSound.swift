import Foundation

enum ClickWaveform: String, Codable, CaseIterable, Identifiable {
    case sine, triangle, square, noise
    var id: String { rawValue }
    var label: String { rawValue.capitalized }
}

/// Everything the click synthesizer needs to render one metronome tick.
struct ClickParameters: Codable, Hashable {
    /// Pitch in Hz (for noise, this is the low-pass cutoff).
    var pitch: Double
    /// 0 = sharp and clicky, 1 = soft and rounded.
    var softness: Double
    var waveform: ClickWaveform
    /// Length in seconds.
    var duration: Double

    static let pitchRange: ClosedRange<Double> = 100...3000
    static let durationRange: ClosedRange<Double> = 0.01...0.3
}

struct SoundPreset: Identifiable, Hashable {
    let id: String
    let name: String
    let params: ClickParameters

    static let classic   = SoundPreset(id: "classic",  name: "Classic Click",
                                       params: ClickParameters(pitch: 1000, softness: 0.15, waveform: .square,   duration: 0.04))
    static let woodBlock = SoundPreset(id: "wood",     name: "Wood Block",
                                       params: ClickParameters(pitch: 800,  softness: 0.35, waveform: .triangle, duration: 0.06))
    static let softTick  = SoundPreset(id: "soft",     name: "Soft Tick",
                                       params: ClickParameters(pitch: 600,  softness: 0.75, waveform: .sine,     duration: 0.08))
    static let beep      = SoundPreset(id: "beep",     name: "Beep",
                                       params: ClickParameters(pitch: 880,  softness: 0.5,  waveform: .sine,     duration: 0.12))
    static let hiHat     = SoundPreset(id: "hihat",    name: "Hi-Hat",
                                       params: ClickParameters(pitch: 2500, softness: 0.2,  waveform: .noise,    duration: 0.06))
    static let thump     = SoundPreset(id: "thump",    name: "Deep Thump",
                                       params: ClickParameters(pitch: 160,  softness: 0.6,  waveform: .sine,     duration: 0.14))

    static let all: [SoundPreset] = [classic, woodBlock, softTick, beep, hiHat, thump]

    static func matching(_ params: ClickParameters) -> SoundPreset? {
        all.first { $0.params == params }
    }
}

/// Where a metronome sound comes from: the built-in synthesizer, or an audio
/// file the user uploaded (stored in the app's Documents/MetronomeSounds folder).
enum SoundSource: Codable, Equatable {
    case synth(ClickParameters)
    case file(name: String)

    var displayName: String {
        switch self {
        case .synth(let p):
            return SoundPreset.matching(p)?.name ?? "Custom synth"
        case .file(let name):
            return SoundLibrary.displayName(name)
        }
    }

    var isFile: Bool {
        if case .file = self { return true }
        return false
    }
}

/// Beat + accent sound configuration.
struct MetronomeSettings: Codable, Equatable {
    var beat: SoundSource = .synth(SoundPreset.classic.params)
    /// `nil` means "derive the accent from the beat sound" (louder and higher).
    var accent: SoundSource? = nil
}

/// Manages uploaded sound files inside the app sandbox.
enum SoundLibrary {
    static var directory: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("MetronomeSounds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func url(for name: String) -> URL {
        directory.appendingPathComponent(name)
    }

    /// Copies a user-picked file into the library and returns its stored name.
    static func importFile(from source: URL) throws -> String {
        let name = String(UUID().uuidString.prefix(8)) + "_" + source.lastPathComponent
        let destination = url(for: name)
        try? FileManager.default.removeItem(at: destination)
        try FileManager.default.copyItem(at: source, to: destination)
        return name
    }

    /// Strips the unique prefix added on import.
    static func displayName(_ storedName: String) -> String {
        if let underscore = storedName.firstIndex(of: "_") {
            return String(storedName[storedName.index(after: underscore)...])
        }
        return storedName
    }
}

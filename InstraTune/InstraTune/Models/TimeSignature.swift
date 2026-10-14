import Foundation

/// How a single beat in the bar is played.
enum BeatAccent: Int, Codable, CaseIterable {
    case normal, accent, silent

    /// Tapping a beat cycles accent → normal → silent → accent …
    var next: BeatAccent {
        switch self {
        case .accent: return .normal
        case .normal: return .silent
        case .silent: return .accent
        }
    }

    var label: String {
        switch self {
        case .accent: return "Accent"
        case .normal: return "Beat"
        case .silent: return "Rest"
        }
    }

    var symbol: String {
        switch self {
        case .accent: return ">"
        case .normal: return "•"
        case .silent: return "–"
        }
    }
}

/// A time signature plus the accent pattern for each beat in the bar.
/// Invariant: `accents.count == beats`.
struct TimeSignature: Equatable, Codable {
    private(set) var beats: Int
    var noteValue: Int
    var accents: [BeatAccent]

    static let allowedNoteValues = [1, 2, 4, 8, 16]
    static let maxBeats = 16

    init(beats: Int, noteValue: Int, accents: [BeatAccent]? = nil) {
        let beats = max(1, min(TimeSignature.maxBeats, beats))
        self.beats = beats
        self.noteValue = noteValue
        if let accents, accents.count == beats {
            self.accents = accents
        } else {
            self.accents = [.accent] + Array(repeating: .normal, count: beats - 1)
        }
    }

    var label: String { "\(beats)/\(noteValue)" }

    /// Changes the number of beats, keeping the existing accent pattern where possible.
    mutating func setBeats(_ n: Int) {
        let n = max(1, min(TimeSignature.maxBeats, n))
        if n > accents.count {
            accents += Array(repeating: .normal, count: n - accents.count)
        } else {
            accents = Array(accents.prefix(n))
        }
        beats = n
    }

    mutating func cycleAccent(at index: Int) {
        guard accents.indices.contains(index) else { return }
        accents[index] = accents[index].next
    }

    func accent(at index: Int) -> BeatAccent {
        accents.indices.contains(index) ? accents[index] : .normal
    }

    /// Common signatures with sensible default groupings.
    static let presets: [TimeSignature] = [
        TimeSignature(beats: 4, noteValue: 4),
        TimeSignature(beats: 3, noteValue: 4),
        TimeSignature(beats: 2, noteValue: 4),
        TimeSignature(beats: 2, noteValue: 2),
        TimeSignature(beats: 6, noteValue: 8,
                      accents: [.accent, .normal, .normal, .accent, .normal, .normal]),
        TimeSignature(beats: 5, noteValue: 4,
                      accents: [.accent, .normal, .normal, .accent, .normal]),
        TimeSignature(beats: 7, noteValue: 8,
                      accents: [.accent, .normal, .accent, .normal, .accent, .normal, .normal]),
        TimeSignature(beats: 9, noteValue: 8,
                      accents: [.accent, .normal, .normal, .accent, .normal, .normal, .accent, .normal, .normal]),
        TimeSignature(beats: 12, noteValue: 8,
                      accents: [.accent, .normal, .normal, .accent, .normal, .normal,
                                .accent, .normal, .normal, .accent, .normal, .normal]),
    ]
}

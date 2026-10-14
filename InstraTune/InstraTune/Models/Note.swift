import Foundation

/// A musical pitch identified by its MIDI note number (A4 = 69).
struct Note: Hashable, Identifiable, Codable {
    let midi: Int
    var id: Int { midi }

    static let names = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]

    var name: String { Note.names[((midi % 12) + 12) % 12] }
    var octave: Int { midi / 12 - 1 }
    var isSharp: Bool { name.contains("♯") }
    var label: String { "\(name)\(octave)" }

    /// Frequency in Hz for a given A4 reference.
    func frequency(a4: Double = 440) -> Double {
        a4 * pow(2, Double(midi - 69) / 12)
    }

    /// The closest note to a frequency and how many cents the frequency is
    /// away from it (negative = flat, positive = sharp).
    static func nearest(to frequency: Double, a4: Double = 440) -> (note: Note, cents: Double) {
        let exact = 69 + 12 * log2(frequency / a4)
        let rounded = Int(exact.rounded())
        return (Note(midi: rounded), (exact - Double(rounded)) * 100)
    }
}

/// Italian tempo markings for a bit of context under the BPM readout.
enum TempoMarking {
    static func name(for bpm: Double) -> String {
        switch bpm {
        case ..<40: return "Grave"
        case ..<60: return "Largo"
        case ..<66: return "Larghetto"
        case ..<76: return "Adagio"
        case ..<108: return "Andante"
        case ..<120: return "Moderato"
        case ..<156: return "Allegro"
        case ..<176: return "Vivace"
        case ..<200: return "Presto"
        default: return "Prestissimo"
        }
    }
}

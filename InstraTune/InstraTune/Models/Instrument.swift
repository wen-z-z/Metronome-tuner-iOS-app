import Foundation

struct InstrumentString: Identifiable, Hashable {
    let id: Int
    let note: Note
    /// Visual thickness in points.
    let gauge: CGFloat
}

enum InstrumentFamily {
    /// Flat body with a round sound hole: guitar, bass, ukulele.
    case guitarLike
    /// Waisted body with f-holes and a scroll: violin, viola, cello.
    case violinLike
}

/// A string instrument the tuner can draw and sound, strings low → high.
struct Instrument: Identifiable, Hashable {
    let id: String
    let name: String
    let symbol: String
    let family: InstrumentFamily
    let strings: [InstrumentString]
    /// Body width as a fraction of the diagram width.
    let bodyWidth: CGFloat
    /// Where the body starts, as a fraction of the diagram height.
    let bodyStart: CGFloat

    static func == (lhs: Instrument, rhs: Instrument) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    var tuningDescription: String {
        strings.map { $0.note.label }.joined(separator: "  ")
    }

    private static func make(_ midis: [Int], gauges: [CGFloat]) -> [InstrumentString] {
        zip(midis, gauges).enumerated().map { index, pair in
            InstrumentString(id: index, note: Note(midi: pair.0), gauge: pair.1)
        }
    }

    static let guitar = Instrument(
        id: "guitar", name: "Guitar", symbol: "guitars.fill", family: .guitarLike,
        strings: make([40, 45, 50, 55, 59, 64], gauges: [4.0, 3.4, 2.8, 2.2, 1.7, 1.4]),
        bodyWidth: 0.82, bodyStart: 0.52)

    static let bassGuitar = Instrument(
        id: "bass", name: "Bass Guitar", symbol: "guitars.fill", family: .guitarLike,
        strings: make([28, 33, 38, 43], gauges: [5.0, 4.2, 3.4, 2.8]),
        bodyWidth: 0.72, bodyStart: 0.6)

    static let ukulele = Instrument(
        id: "ukulele", name: "Ukulele", symbol: "guitars", family: .guitarLike,
        strings: make([67, 60, 64, 69], gauges: [2.0, 2.6, 2.2, 1.8]),
        bodyWidth: 0.6, bodyStart: 0.55)

    static let violin = Instrument(
        id: "violin", name: "Violin", symbol: "music.quarternote.3", family: .violinLike,
        strings: make([55, 62, 69, 76], gauges: [3.0, 2.4, 1.9, 1.4]),
        bodyWidth: 0.7, bodyStart: 0.5)

    static let viola = Instrument(
        id: "viola", name: "Viola", symbol: "music.quarternote.3", family: .violinLike,
        strings: make([48, 55, 62, 69], gauges: [3.4, 2.8, 2.2, 1.7]),
        bodyWidth: 0.74, bodyStart: 0.5)

    static let cello = Instrument(
        id: "cello", name: "Cello", symbol: "music.quarternote.3", family: .violinLike,
        strings: make([36, 43, 50, 57], gauges: [4.4, 3.6, 2.9, 2.3]),
        bodyWidth: 0.84, bodyStart: 0.46)

    static let all: [Instrument] = [guitar, bassGuitar, ukulele, violin, viola, cello]
}

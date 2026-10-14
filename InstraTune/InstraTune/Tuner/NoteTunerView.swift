import SwiftUI

/// Note tuner: a scrollable piano. Tapping a key sounds a steady tone at that
/// note's exact frequency; tapping it again (or Stop) silences it.
struct NoteTunerView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer
    let a4: Double

    @State private var activeMidi: Int?

    private let lowMidi = 36   // C2
    private let highMidi = 95  // B6

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                if let midi = activeMidi {
                    let note = Note(midi: midi)
                    Text(note.label)
                        .font(.system(size: 64, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.honeydew)
                    Text(String(format: "%.2f Hz", note.frequency(a4: a4)))
                        .font(.title3.monospacedDigit())
                        .foregroundStyle(Theme.silver)
                } else {
                    Text("Tap a key")
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .foregroundStyle(Theme.honeydew)
                    Text("The note plays until you tap it again")
                        .font(.subheadline)
                        .foregroundStyle(Theme.silver)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
            .card()

            PianoKeyboard(lowMidi: lowMidi, highMidi: highMidi, activeMidi: activeMidi) { midi in
                toggle(midi)
            }
            .frame(height: 220)

            Button {
                activeMidi = nil
                tonePlayer.stop()
            } label: {
                Label("Stop", systemImage: "stop.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.honeydew)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(activeMidi == nil ? Theme.charcoal : Theme.spruce))
            }
            .buttonStyle(.plain)
            .disabled(activeMidi == nil)

            Spacer(minLength: 0)
        }
        .onChange(of: a4) { _, newValue in
            if let midi = activeMidi {
                tonePlayer.play(note: Note(midi: midi), a4: newValue)
            }
        }
        .onDisappear {
            activeMidi = nil
            tonePlayer.stop()
        }
    }

    private func toggle(_ midi: Int) {
        if activeMidi == midi {
            activeMidi = nil
            tonePlayer.stop()
        } else {
            activeMidi = midi
            tonePlayer.play(note: Note(midi: midi), a4: a4)
        }
    }
}

/// Horizontally scrolling piano keyboard with toggleable keys.
struct PianoKeyboard: View {
    let lowMidi: Int
    let highMidi: Int
    let activeMidi: Int?
    let onTap: (Int) -> Void

    private let whiteWidth: CGFloat = 46
    private let spacing: CGFloat = 2
    private var blackWidth: CGFloat { whiteWidth * 0.62 }

    private var whiteNotes: [Note] {
        (lowMidi...highMidi).map { Note(midi: $0) }.filter { !$0.isSharp }
    }

    private var blackNotes: [Note] {
        (lowMidi...highMidi).map { Note(midi: $0) }.filter { $0.isSharp }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                ZStack(alignment: .topLeading) {
                    HStack(spacing: spacing) {
                        ForEach(whiteNotes) { note in
                            WhiteKey(note: note, isActive: note.midi == activeMidi) {
                                onTap(note.midi)
                            }
                            .frame(width: whiteWidth)
                            .id(note.midi)
                        }
                    }
                    ForEach(blackNotes) { note in
                        BlackKey(note: note, isActive: note.midi == activeMidi) {
                            onTap(note.midi)
                        }
                        .frame(width: blackWidth, height: 130)
                        .offset(x: blackKeyOffset(for: note))
                    }
                }
                .padding(.horizontal, 8)
            }
            .onAppear {
                // Start a few keys below middle C so C4 sits comfortably on screen.
                proxy.scrollTo(57, anchor: .leading)
            }
        }
    }

    /// Horizontal offset of a black key: centred on the gap after its lower white neighbour.
    private func blackKeyOffset(for note: Note) -> CGFloat {
        let whitesBefore = (lowMidi..<note.midi).filter { !Note(midi: $0).isSharp }.count
        return CGFloat(whitesBefore) * (whiteWidth + spacing) - blackWidth / 2 - spacing / 2
    }
}

struct WhiteKey: View {
    let note: Note
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isActive ? Theme.spruce : Theme.honeydew)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.charcoal.opacity(0.4), lineWidth: 1)
                    )
                Text(note.label)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(isActive ? Theme.honeydew : Theme.charcoal)
                    .padding(.bottom, 8)
            }
            .shadow(color: isActive ? Theme.spruce.opacity(0.8) : .clear, radius: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(note.label)
    }
}

struct BlackKey: View {
    let note: Note
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(isActive ? Theme.spruce : Theme.prussian)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .stroke(Theme.silver.opacity(0.5), lineWidth: 1)
                    )
                Text(note.name)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(isActive ? Theme.honeydew : Theme.silver)
                    .padding(.bottom, 6)
            }
            .shadow(color: isActive ? Theme.spruce.opacity(0.9) : .black.opacity(0.4), radius: 4, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(note.label)
    }
}

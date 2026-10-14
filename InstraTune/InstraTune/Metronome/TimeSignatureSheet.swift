import SwiftUI

/// Pop-up for choosing a time signature and editing which beats are accented.
struct TimeSignatureSheet: View {
    @EnvironmentObject private var metronome: MetronomeEngine
    @Environment(\.dismiss) private var dismiss

    private var beatsBinding: Binding<Int> {
        Binding(get: { metronome.timeSignature.beats },
                set: { metronome.timeSignature.setBeats($0) })
    }

    private var noteValueBinding: Binding<Int> {
        Binding(get: { metronome.timeSignature.noteValue },
                set: { metronome.timeSignature.noteValue = $0 })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    presetsSection
                    pickerSection
                    accentSection
                }
                .padding()
            }
            .background(Theme.prussian.ignoresSafeArea())
            .navigationTitle("Time signature")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.honeydew)
                }
            }
        }
    }

    // MARK: Sections

    private var presetsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Common").font(.headline).foregroundStyle(Theme.honeydew)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: 8)], spacing: 8) {
                ForEach(TimeSignature.presets, id: \.label) { preset in
                    let selected = preset.beats == metronome.timeSignature.beats
                        && preset.noteValue == metronome.timeSignature.noteValue
                    Button {
                        metronome.timeSignature = preset
                    } label: {
                        Text(preset.label)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selected ? Theme.honeydew : Theme.silver)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(selected ? Theme.spruce : Theme.prussian)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .card()
    }

    private var pickerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Custom").font(.headline).foregroundStyle(Theme.honeydew)
            HStack(spacing: 0) {
                VStack(spacing: 2) {
                    Text("Beats per bar").font(.caption).foregroundStyle(Theme.silver)
                    Picker("Beats", selection: beatsBinding) {
                        ForEach(1...TimeSignature.maxBeats, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 130)
                }
                Text("/")
                    .font(.system(size: 44, weight: .light))
                    .foregroundStyle(Theme.silver)
                    .padding(.top, 18)
                VStack(spacing: 2) {
                    Text("Note value").font(.caption).foregroundStyle(Theme.silver)
                    Picker("Note value", selection: noteValueBinding) {
                        ForEach(TimeSignature.allowedNoteValues, id: \.self) { n in
                            Text("\(n)").tag(n)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(height: 130)
                }
            }
            Text("Tempo counts the note value: in 6/8 each eighth note gets one tick.")
                .font(.caption)
                .foregroundStyle(Theme.silver)
        }
        .card()
    }

    private var accentSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Accents").font(.headline).foregroundStyle(Theme.honeydew)
            Text("Tap a beat to cycle it: accent → beat → rest.")
                .font(.caption)
                .foregroundStyle(Theme.silver)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 56), spacing: 8)], spacing: 8) {
                ForEach(0..<metronome.timeSignature.beats, id: \.self) { index in
                    let accent = metronome.timeSignature.accent(at: index)
                    Button {
                        metronome.timeSignature.cycleAccent(at: index)
                    } label: {
                        VStack(spacing: 4) {
                            Text("\(index + 1)")
                                .font(.title3.weight(.bold))
                            Text(accent.label)
                                .font(.caption2)
                        }
                        .foregroundStyle(accent == .silent ? Theme.silver : Theme.honeydew)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(background(for: accent))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Theme.silver.opacity(0.4), lineWidth: accent == .silent ? 1 : 0)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack(spacing: 12) {
                legend(color: Theme.spruce, text: "Accent")
                legend(color: Theme.prussian, text: "Beat")
                legend(color: .clear, text: "Rest", stroked: true)
            }
            .padding(.top, 4)
        }
        .card()
    }

    private func background(for accent: BeatAccent) -> Color {
        switch accent {
        case .accent: return Theme.spruce
        case .normal: return Theme.prussian
        case .silent: return .clear
        }
    }

    private func legend(color: Color, text: String, stroked: Bool = false) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(color)
                .overlay(RoundedRectangle(cornerRadius: 4)
                    .stroke(Theme.silver.opacity(0.4), lineWidth: stroked ? 1 : 0))
                .frame(width: 14, height: 14)
            Text(text).font(.caption).foregroundStyle(Theme.silver)
        }
    }
}

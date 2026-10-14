import SwiftUI

struct MetronomeView: View {
    @EnvironmentObject private var metronome: MetronomeEngine
    @State private var showTimeSignature = false
    @State private var showSound = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                BeatIndicator(timeSignature: metronome.timeSignature,
                              currentBeat: metronome.currentBeat,
                              isRunning: metronome.isRunning)
                    .card()

                tempoCard

                HStack(spacing: 12) {
                    SettingButton(title: "Time signature",
                                  value: metronome.timeSignature.label,
                                  icon: "music.note.list") { showTimeSignature = true }
                    SettingButton(title: "Sound",
                                  value: metronome.settings.beat.displayName,
                                  icon: "speaker.wave.2.fill") { showSound = true }
                }

                if let error = metronome.loadError {
                    Text(error)
                        .font(.footnote)
                        .foregroundStyle(Theme.honeydew)
                        .padding(10)
                        .frame(maxWidth: .infinity)
                        .background(Theme.spruce.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                }

                playButton
                    .padding(.top, 8)
            }
            .padding()
        }
        .sheet(isPresented: $showTimeSignature) {
            TimeSignatureSheet()
                .environmentObject(metronome)
                .presentationDetents([.large])
        }
        .sheet(isPresented: $showSound) {
            SoundSettingsSheet()
                .environmentObject(metronome)
                .presentationDetents([.large])
        }
    }

    private var tempoCard: some View {
        VStack(spacing: 6) {
            Text("\(Int(metronome.bpm.rounded()))")
                .font(.system(size: 76, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(Theme.honeydew)
            Text("BPM · \(TempoMarking.name(for: metronome.bpm))")
                .font(.subheadline)
                .foregroundStyle(Theme.silver)

            HStack(spacing: 12) {
                RoundIconButton("minus") {
                    metronome.bpm = max(MetronomeEngine.bpmRange.lowerBound, metronome.bpm - 1)
                }
                Slider(value: $metronome.bpm, in: MetronomeEngine.bpmRange, step: 1)
                    .tint(Theme.honeydew)
                RoundIconButton("plus") {
                    metronome.bpm = min(MetronomeEngine.bpmRange.upperBound, metronome.bpm + 1)
                }
            }
            .padding(.top, 6)

            Button {
                metronome.tapTempo()
            } label: {
                Label("Tap tempo", systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.honeydew)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(Theme.prussian))
            }
            .buttonStyle(.plain)
        }
        .card()
    }

    private var playButton: some View {
        Button {
            metronome.toggle()
        } label: {
            Image(systemName: metronome.isRunning ? "stop.fill" : "play.fill")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.honeydew)
                .frame(width: 92, height: 92)
                .background(Circle().fill(Theme.spruce))
                .shadow(color: Theme.spruce.opacity(0.7), radius: metronome.isRunning ? 18 : 6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(metronome.isRunning ? "Stop metronome" : "Start metronome")
    }
}

/// One dot per beat in the bar; the current beat lights up while running.
struct BeatIndicator: View {
    let timeSignature: TimeSignature
    let currentBeat: Int
    let isRunning: Bool

    var body: some View {
        VStack(spacing: 10) {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 36), spacing: 8)], spacing: 10) {
                ForEach(0..<timeSignature.beats, id: \.self) { index in
                    let accent = timeSignature.accent(at: index)
                    let isCurrent = isRunning && currentBeat == index
                    ZStack {
                        Circle()
                            .fill(fillColor(accent: accent, isCurrent: isCurrent))
                            .overlay(
                                Circle().stroke(Theme.silver.opacity(0.5),
                                                lineWidth: accent == .silent ? 1.5 : 0)
                            )
                        Text("\(index + 1)")
                            .font(.caption2.bold())
                            .foregroundStyle(isCurrent ? Theme.prussian : Theme.silver)
                    }
                    .frame(width: accent == .accent ? 36 : 28, height: 36)
                    .scaleEffect(isCurrent ? 1.18 : 1)
                    .animation(.easeOut(duration: 0.08), value: isCurrent)
                }
            }
            Text("\(timeSignature.label) · tap Time signature to edit accents")
                .font(.caption)
                .foregroundStyle(Theme.silver)
        }
    }

    private func fillColor(accent: BeatAccent, isCurrent: Bool) -> Color {
        if isCurrent { return Theme.honeydew }
        switch accent {
        case .accent: return Theme.silver.opacity(0.9)
        case .normal: return Theme.silver.opacity(0.35)
        case .silent: return .clear
        }
    }
}

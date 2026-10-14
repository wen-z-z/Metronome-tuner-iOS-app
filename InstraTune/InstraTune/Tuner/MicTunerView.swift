import SwiftUI

/// Microphone tuner: shows the nearest note, a flat/sharp slider, and turns
/// green when the note is within tolerance.
struct MicTunerView: View {
    @EnvironmentObject private var detector: PitchDetector

    let a4: Double
    var onPermissionDenied: () -> Void

    private static let inTuneCents = 5.0

    private var reading: (note: Note, cents: Double)? {
        detector.frequency.map { Note.nearest(to: $0, a4: a4) }
    }

    private var inTune: Bool {
        guard let reading else { return false }
        return abs(reading.cents) <= Self.inTuneCents
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            ZStack {
                Circle()
                    .fill(inTune ? Theme.inTune : Theme.charcoal)
                    .frame(width: 220, height: 220)
                    .shadow(color: inTune ? Theme.inTune.opacity(0.6) : .clear, radius: 24)
                    .animation(.easeInOut(duration: 0.15), value: inTune)
                VStack(spacing: 0) {
                    Text(reading?.note.name ?? "–")
                        .font(.system(size: 88, weight: .bold, design: .rounded))
                        .foregroundStyle(inTune ? Theme.prussian : Theme.honeydew)
                    Text(reading.map { "octave \($0.note.octave)" } ?? "listening")
                        .font(.subheadline)
                        .foregroundStyle(inTune ? Theme.prussian.opacity(0.8) : Theme.silver)
                }
            }

            CentsGauge(cents: reading?.cents, inTune: inTune)
                .frame(height: 64)
                .padding(.horizontal, 8)

            HStack(spacing: 10) {
                stat("Heard", detector.frequency.map { String(format: "%.1f Hz", $0) } ?? "—")
                stat("Offset", reading.map { String(format: "%+.0f ¢", $0.cents) } ?? "—")
                stat("Target", reading.map { String(format: "%.1f Hz", $0.note.frequency(a4: a4)) } ?? "—")
            }

            levelMeter

            Spacer(minLength: 0)
        }
        .onAppear(perform: startIfAllowed)
        .onDisappear { detector.stop() }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(title).font(.caption).foregroundStyle(Theme.silver)
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(Theme.honeydew)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.charcoal, in: RoundedRectangle(cornerRadius: 12))
    }

    private var levelMeter: some View {
        HStack(spacing: 8) {
            Image(systemName: detector.isListening ? "mic.fill" : "mic.slash")
                .font(.caption)
                .foregroundStyle(Theme.silver)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.charcoal)
                    Capsule()
                        .fill(Theme.honeydew.opacity(0.8))
                        .frame(width: geo.size.width * CGFloat(detector.inputLevel))
                        .animation(.linear(duration: 0.08), value: detector.inputLevel)
                }
            }
            .frame(height: 6)
        }
        .padding(.horizontal, 24)
    }

    private func startIfAllowed() {
        switch detector.permission {
        case .granted:
            detector.start()
        case .denied:
            onPermissionDenied()
        case .undetermined:
            detector.requestPermission { granted in
                if granted {
                    detector.start()
                } else {
                    onPermissionDenied()
                }
            }
        }
    }
}

/// Horizontal flat ← → sharp gauge from -50 to +50 cents.
struct CentsGauge: View {
    let cents: Double?
    let inTune: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let clamped = min(50, max(-50, cents ?? 0))
            let x = width * CGFloat((clamped + 50) / 100)

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.charcoal)
                    .frame(height: 14)
                    .frame(maxHeight: .infinity, alignment: .center)

                // Green "in tune" window around the centre.
                RoundedRectangle(cornerRadius: 6)
                    .fill(Theme.inTune.opacity(0.35))
                    .frame(width: width * 0.1, height: 14)
                    .offset(x: width * 0.45)

                // Tick marks.
                ForEach([-50.0, -25, 0, 25, 50], id: \.self) { tick in
                    Rectangle()
                        .fill(Theme.silver.opacity(tick == 0 ? 0.9 : 0.4))
                        .frame(width: tick == 0 ? 2 : 1, height: tick == 0 ? 30 : 20)
                        .offset(x: width * CGFloat((tick + 50) / 100) - (tick == 0 ? 1 : 0.5))
                }

                // Needle.
                Capsule()
                    .fill(cents == nil ? Theme.silver.opacity(0.4) : (inTune ? Theme.inTune : Theme.honeydew))
                    .frame(width: 6, height: height)
                    .shadow(color: inTune ? Theme.inTune : .clear, radius: 8)
                    .offset(x: x - 3)
                    .animation(.easeOut(duration: 0.12), value: x)
            }
            .overlay(alignment: .bottomLeading) {
                Text("♭ flat").font(.caption2).foregroundStyle(Theme.silver)
            }
            .overlay(alignment: .bottomTrailing) {
                Text("sharp ♯").font(.caption2).foregroundStyle(Theme.silver)
            }
        }
    }
}

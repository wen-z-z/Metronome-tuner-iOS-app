import SwiftUI
import UIKit

enum TunerMode: String, CaseIterable, Identifiable {
    case microphone = "Microphone"
    case note = "Note"
    case instrument = "Instrument"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .microphone: return "mic.fill"
        case .note: return "pianokeys"
        case .instrument: return "guitars.fill"
        }
    }
}

/// Tuner section: three mutually exclusive modes plus A4 calibration.
struct TunerView: View {
    @EnvironmentObject private var tonePlayer: TonePlayer
    @EnvironmentObject private var pitchDetector: PitchDetector

    @AppStorage("tuner.a4") private var a4: Double = 440
    @State private var mode: TunerMode = .microphone
    @State private var showDeniedNotice = false

    var body: some View {
        VStack(spacing: 14) {
            TunerModeSelector(selection: $mode)

            if showDeniedNotice {
                deniedNotice
            }

            Group {
                switch mode {
                case .microphone:
                    MicTunerView(a4: a4) {
                        // Fall back to the note tuner when the mic isn't allowed.
                        withAnimation { mode = .note }
                        showDeniedNotice = true
                    }
                case .note:
                    NoteTunerView(a4: a4)
                case .instrument:
                    InstrumentTunerView(a4: a4)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            calibrationRow
        }
        .padding()
        .onAppear {
            pitchDetector.refreshPermission()
            if pitchDetector.permission == .denied {
                mode = .note
                showDeniedNotice = true
            }
        }
        .onChange(of: mode) { _, _ in
            // Only one tuner may be active at a time.
            tonePlayer.stop()
            pitchDetector.stop()
        }
        .onDisappear {
            tonePlayer.stop()
            pitchDetector.stop()
        }
    }

    private var calibrationRow: some View {
        HStack {
            Text("Reference pitch")
                .font(.footnote)
                .foregroundStyle(Theme.silver)
            Spacer()
            Stepper(value: $a4, in: 415...466, step: 1) {
                Text("A4 = \(Int(a4)) Hz")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.honeydew)
            }
            .fixedSize()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Theme.charcoal, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var deniedNotice: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.slash.fill").foregroundStyle(Theme.silver)
            Text("Microphone access is off, so the Note tuner is selected.")
                .font(.caption)
                .foregroundStyle(Theme.honeydew)
            Spacer()
            if let url = URL(string: UIApplication.openSettingsURLString) {
                Link("Settings", destination: url)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.honeydew)
            }
            Button {
                withAnimation { showDeniedNotice = false }
            } label: {
                Image(systemName: "xmark").font(.caption).foregroundStyle(Theme.silver)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(Theme.spruce.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
    }
}

/// Three buttons; exactly one is highlighted at a time.
struct TunerModeSelector: View {
    @Binding var selection: TunerMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(TunerMode.allCases) { mode in
                let isSelected = mode == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = mode
                    }
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 20, weight: .semibold))
                        Text(mode.rawValue)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(isSelected ? Theme.honeydew : Theme.silver)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? Theme.spruce : Theme.charcoal)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Theme.honeydew.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
                    )
                    .scaleEffect(isSelected ? 1.03 : 1)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
    }
}

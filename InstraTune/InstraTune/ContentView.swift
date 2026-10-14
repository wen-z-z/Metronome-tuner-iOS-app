import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case tuner = "Tuner"
    case metronome = "Metronome"

    var id: String { rawValue }
    var icon: String {
        switch self {
        case .tuner: return "tuningfork"
        case .metronome: return "metronome"
        }
    }
}

/// Root view. The app opens on the tuner; the top switcher moves between sections.
struct ContentView: View {
    @EnvironmentObject private var metronome: MetronomeEngine
    @EnvironmentObject private var tonePlayer: TonePlayer
    @EnvironmentObject private var pitchDetector: PitchDetector

    @State private var section: AppSection = .tuner

    var body: some View {
        ZStack {
            Theme.prussian.ignoresSafeArea()
            VStack(spacing: 0) {
                SectionSwitcher(selection: $section)
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 4)

                Group {
                    switch section {
                    case .tuner: TunerView()
                    case .metronome: MetronomeView()
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: section) { _, newValue in
            // Keep the two halves of the app from talking over each other.
            switch newValue {
            case .metronome:
                tonePlayer.stop()
                pitchDetector.stop()
            case .tuner:
                metronome.stop()
            }
        }
    }
}

/// Two-way pill switcher between Tuner and Metronome.
struct SectionSwitcher: View {
    @Binding var selection: AppSection
    @Namespace private var pill

    var body: some View {
        HStack(spacing: 4) {
            ForEach(AppSection.allCases) { item in
                let isSelected = item == selection
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                        selection = item
                    }
                } label: {
                    Label(item.rawValue, systemImage: item.icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Theme.honeydew : Theme.silver)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            if isSelected {
                                Capsule()
                                    .fill(Theme.spruce)
                                    .matchedGeometryEffect(id: "pill", in: pill)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.charcoal))
    }
}

#Preview {
    ContentView()
        .environmentObject(MetronomeEngine())
        .environmentObject(TonePlayer())
        .environmentObject(PitchDetector())
}

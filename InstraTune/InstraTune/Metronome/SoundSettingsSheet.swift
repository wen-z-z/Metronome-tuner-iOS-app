import SwiftUI
import UniformTypeIdentifiers

/// Pop-up for shaping the metronome sound: presets, pitch & softness, custom
/// uploaded audio files, and a separately configurable accent sound.
struct SoundSettingsSheet: View {
    @EnvironmentObject private var metronome: MetronomeEngine
    @Environment(\.dismiss) private var dismiss

    private enum ImportTarget { case beat, accent }

    @State private var importTarget: ImportTarget = .beat
    @State private var showImporter = false
    @State private var importError: String?

    private static let audioTypes: [UTType] = [.mp3, .wav, .aiff, .mpeg4Audio, .audio]

    private var beatBinding: Binding<SoundSource> {
        Binding(get: { metronome.settings.beat },
                set: { metronome.settings.beat = $0 })
    }

    private var accentBinding: Binding<SoundSource> {
        Binding(get: { metronome.settings.accent ?? metronome.settings.beat },
                set: { metronome.settings.accent = $0 })
    }

    private var deriveAccentBinding: Binding<Bool> {
        Binding(get: { metronome.settings.accent == nil },
                set: { derive in
                    metronome.settings.accent = derive ? nil : metronome.settings.beat
                })
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SoundSourceEditor(title: "Beat sound",
                                      source: beatBinding,
                                      onUpload: { beginImport(.beat) },
                                      onPreview: { metronome.preview(.beat) })

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Accented beat").font(.headline).foregroundStyle(Theme.honeydew)
                        Toggle(isOn: deriveAccentBinding) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Derive from beat sound")
                                    .foregroundStyle(Theme.honeydew)
                                Text("Louder and pitched up automatically")
                                    .font(.caption)
                                    .foregroundStyle(Theme.silver)
                            }
                        }
                        .tint(Theme.spruce)
                        Button {
                            metronome.preview(.accent)
                        } label: {
                            Label("Preview accent", systemImage: "play.circle")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(Theme.honeydew)
                        }
                        .buttonStyle(.plain)
                    }
                    .card()

                    if metronome.settings.accent != nil {
                        SoundSourceEditor(title: "Accent sound",
                                          source: accentBinding,
                                          onUpload: { beginImport(.accent) },
                                          onPreview: { metronome.preview(.accent) })
                    }

                    if let importError {
                        Text(importError)
                            .font(.footnote)
                            .foregroundStyle(Theme.honeydew)
                            .padding(10)
                            .frame(maxWidth: .infinity)
                            .background(Theme.spruce.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
                .padding()
            }
            .background(Theme.prussian.ignoresSafeArea())
            .navigationTitle("Metronome sound")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.honeydew)
                }
            }
            .fileImporter(isPresented: $showImporter,
                          allowedContentTypes: Self.audioTypes,
                          allowsMultipleSelection: false) { result in
                handleImport(result)
            }
        }
    }

    private func beginImport(_ target: ImportTarget) {
        importTarget = target
        importError = nil
        showImporter = true
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error):
            importError = "Couldn't open that file: \(error.localizedDescription)"
        case .success(let urls):
            guard let url = urls.first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            do {
                let name = try SoundLibrary.importFile(from: url)
                switch importTarget {
                case .beat: metronome.settings.beat = .file(name: name)
                case .accent: metronome.settings.accent = .file(name: name)
                }
            } catch {
                importError = "Couldn't import the file: \(error.localizedDescription)"
            }
        }
    }
}

/// Editor for one `SoundSource`: dropdown of presets / upload, plus pitch,
/// softness, waveform and length controls for synthesized sounds.
struct SoundSourceEditor: View {
    let title: String
    @Binding var source: SoundSource
    var onUpload: () -> Void
    var onPreview: () -> Void

    private var params: Binding<ClickParameters> {
        Binding(get: {
            if case .synth(let p) = source { return p }
            return SoundPreset.classic.params
        }, set: { source = .synth($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title).font(.headline).foregroundStyle(Theme.honeydew)
                Spacer()
                Button(action: onPreview) {
                    Label("Preview", systemImage: "play.circle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.honeydew)
                }
                .buttonStyle(.plain)
            }

            Menu {
                ForEach(SoundPreset.all) { preset in
                    Button(preset.name) { source = .synth(preset.params) }
                }
                Divider()
                Button(action: onUpload) {
                    Label("Upload audio file (MP3, WAV…)", systemImage: "square.and.arrow.up")
                }
            } label: {
                HStack {
                    Image(systemName: source.isFile ? "waveform" : "slider.horizontal.3")
                    Text(source.displayName)
                        .lineLimit(1)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down").font(.caption)
                }
                .foregroundStyle(Theme.honeydew)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12).fill(Theme.prussian))
            }

            switch source {
            case .synth:
                synthControls
            case .file(let name):
                HStack(spacing: 10) {
                    Image(systemName: "doc.fill").foregroundStyle(Theme.silver)
                    Text(SoundLibrary.displayName(name))
                        .font(.subheadline)
                        .foregroundStyle(Theme.honeydew)
                        .lineLimit(1)
                    Spacer()
                    Button("Replace", action: onUpload)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.honeydew)
                }
                Text("The first 3 seconds of the file are used as the click.")
                    .font(.caption)
                    .foregroundStyle(Theme.silver)
            }
        }
        .card()
    }

    private var synthControls: some View {
        VStack(spacing: 12) {
            labeledSlider(title: "Pitch",
                          value: params.pitch,
                          range: ClickParameters.pitchRange,
                          display: "\(Int(params.wrappedValue.pitch)) Hz")
            labeledSlider(title: "Softness",
                          value: params.softness,
                          range: 0...1,
                          display: "\(Int(params.wrappedValue.softness * 100))%")
            labeledSlider(title: "Length",
                          value: params.duration,
                          range: ClickParameters.durationRange,
                          display: "\(Int(params.wrappedValue.duration * 1000)) ms")

            VStack(alignment: .leading, spacing: 6) {
                Text("Waveform").font(.caption).foregroundStyle(Theme.silver)
                Picker("Waveform", selection: params.waveform) {
                    ForEach(ClickWaveform.allCases) { wave in
                        Text(wave.label).tag(wave)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
    }

    private func labeledSlider(title: String,
                               value: Binding<Double>,
                               range: ClosedRange<Double>,
                               display: String) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text(title).font(.caption).foregroundStyle(Theme.silver)
                Spacer()
                Text(display).font(.caption.monospacedDigit()).foregroundStyle(Theme.honeydew)
            }
            Slider(value: value, in: range)
                .tint(Theme.honeydew)
        }
    }
}

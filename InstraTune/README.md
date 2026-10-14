# InstraTune — metronome + tuner for iOS

A native SwiftUI app (iOS 17+, Xcode 16+) that is both a metronome and a tuner,
styled with the Prussian Blue / Charcoal Blue / Silver / Honeydew / Dark Spruce palette.

## Opening the project

1. Unzip and open `InstraTune.xcodeproj` in Xcode 16 or newer.
2. Select the **InstraTune** target → *Signing & Capabilities* → pick your team.
3. Run on a **physical iPhone** for the microphone tuner (the Simulator has no
   usable mic input; everything else works in the Simulator).

The project uses Xcode's folder-synchronised groups, so any file you drop into the
`InstraTune/` folder is picked up automatically. If an older Xcode refuses to open the
project, create a new *iOS App* project named `InstraTune`, delete its generated
`ContentView.swift`/`InstraTuneApp.swift`, drag the contents of the `InstraTune/` folder in,
and add `NSMicrophoneUsageDescription` to the target's Info settings.

## Where each exit stage lives

| Stage | What | Files |
|---|---|---|
| 1 | Opens on the tuner; pill buttons switch Tuner ⇄ Metronome | `ContentView.swift`, `Theme.swift`, `InstraTuneApp.swift` |
| 2 | Metronome keeps time for the chosen time signature | `Audio/MetronomeEngine.swift`, `Models/TimeSignature.swift`, `Metronome/MetronomeView.swift` |
| 3 | Pop-ups for time signature and sound; sound can be switched | `Metronome/TimeSignatureSheet.swift`, `Metronome/SoundSettingsSheet.swift`, `Audio/ClickSynth.swift`, `Models/MetronomeSound.swift` |
| 4 | Upload an MP3 (or WAV/AIFF/M4A) and use it as the click; separate accent sound | `SoundSettingsSheet.swift` (file importer), `AudioFileLoader` in `ClickSynth.swift`, `MetronomeEngine.rebuildBuffers` |
| 5 | Three mutually-exclusive tuner buttons with visual state | `Tuner/TunerView.swift` (`TunerModeSelector`) |
| 6 | Microphone tuner with permission flow; falls back to Note tuner if denied | `Audio/PitchDetector.swift`, `Tuner/MicTunerView.swift`, `TunerView.swift` |
| 7 | Note tuner plays a steady, accurate tone for the chosen piano key | `Audio/TonePlayer.swift`, `Tuner/NoteTunerView.swift` |
| 8 | Instrument tuner: guitar, bass, ukulele, violin, viola, cello; tap a string to sound it, active string glows | `Models/Instrument.swift`, `Tuner/InstrumentTunerView.swift` |

## How it works

**Metronome timing.** `MetronomeEngine` renders audio through an `AVAudioSourceNode`.
The render callback counts frames and inserts a click buffer exactly on each beat
boundary, so the pulse is sample-accurate and independent of UI timers. BPM counts the
note value in the denominator (in 6/8 at 120, each eighth note gets a tick). Each beat
in the bar can be an **accent**, a normal **beat**, or a **rest** — tap a beat in the
time-signature pop-up to cycle it. Tempo, time signature and sound settings persist
between launches.

**Metronome sound.** The sound pop-up has a dropdown of presets (Classic Click, Wood
Block, Soft Tick, Beep, Hi-Hat, Deep Thump) plus *pitch*, *softness*, *length* and
*waveform* controls for the built-in synthesizer, and an *Upload audio file* option that
copies the chosen file into the app sandbox and uses its first three seconds as the
click. The accented beat can either be derived automatically (louder, pitched up — for
uploaded files it is resampled 20 % faster) or given its own preset/file.

**Microphone tuner.** `PitchDetector` taps the input node and runs the McLeod pitch
method (normalised autocorrelation with key-maximum picking and parabolic
interpolation), then median-filters the result. The big circle turns green and the
needle lands in the green window when the note is within ±5 cents. If microphone
permission is denied the tuner switches to the Note tuner and shows a banner with a
link to Settings.

**Note & instrument tuners.** `TonePlayer` synthesises a warm tone (fundamental plus a
few harmonics) at the exact frequency of the selected note, with smooth gain/frequency
glides so nothing clicks. The piano spans C2–B6; the instrument view draws a stylised
headstock, neck, body and strings, and each string is a button that toggles its pitch.
The reference pitch (A4) is adjustable from 415–466 Hz and applies to every tuner mode.

## Project layout

```
InstraTune/
├── InstraTuneApp.swift          App entry; shares the three audio objects
├── ContentView.swift           Tuner/Metronome switcher
├── Theme.swift                 Palette + reusable card/button styles
├── Audio/
│   ├── AudioSession.swift      AVAudioSession configuration
│   ├── MetronomeEngine.swift   Sample-accurate metronome
│   ├── ClickSynth.swift        Click synthesizer + audio file loader
│   ├── TonePlayer.swift        Reference tone generator
│   └── PitchDetector.swift     Microphone pitch detection
├── Models/
│   ├── Note.swift              MIDI ↔ frequency, nearest-note/cents
│   ├── TimeSignature.swift     Beats, note value, accent pattern, presets
│   ├── MetronomeSound.swift    Presets, SoundSource, uploaded-file library
│   └── Instrument.swift        Tunings & drawing parameters
├── Metronome/
│   ├── MetronomeView.swift
│   ├── TimeSignatureSheet.swift
│   └── SoundSettingsSheet.swift
└── Tuner/
    ├── TunerView.swift         Mode selector + A4 calibration
    ├── MicTunerView.swift
    ├── NoteTunerView.swift     Piano keyboard
    └── InstrumentTunerView.swift
```

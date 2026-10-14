import SwiftUI

@main
struct InstraTuneApp: App {
    @StateObject private var metronome = MetronomeEngine()
    @StateObject private var tonePlayer = TonePlayer()
    @StateObject private var pitchDetector = PitchDetector()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(metronome)
                .environmentObject(tonePlayer)
                .environmentObject(pitchDetector)
                .preferredColorScheme(.dark)
        }
    }
}

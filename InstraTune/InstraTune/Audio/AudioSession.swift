import AVFoundation

/// Central place for AVAudioSession configuration.
enum AudioSession {
    /// Configures the shared session for playback, or play-and-record when the
    /// microphone tuner is active. Avoids needless category churn.
    static func configure(recording: Bool) {
        let session = AVAudioSession.sharedInstance()
        do {
            if recording {
                if session.category != .playAndRecord {
                    try session.setCategory(.playAndRecord,
                                            mode: .default,
                                            options: [.defaultToSpeaker, .allowBluetoothA2DP])
                }
            } else if session.category != .playback && session.category != .playAndRecord {
                try session.setCategory(.playback, mode: .default, options: [])
            }
            try session.setActive(true)
        } catch {
            print("AudioSession configuration failed: \(error)")
        }
    }
}

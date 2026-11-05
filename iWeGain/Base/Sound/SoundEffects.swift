import AVFoundation
import OSLog

/// Short sounds the app plays itself. The ambient audio session stays quiet with the silent switch on, and
/// lowers other audio (music) from the first tick through the chime, without it coming back up between the ticks.
final class SoundEffects {
    private static let logger = Logger(subsystem: "com.iwelogic.gain", category: "Sound")
    /// A little over the second between ticks, so the music stays down from one tick to the next.
    private static let tickDuck: Duration = .milliseconds(1500)
    /// The length of rest_over plus a little, before other audio comes back up.
    private static let chimeDuck: Duration = .seconds(1)

    // Loaded up front, so the first rest already has them ready.
    private let players: [RestSound: AVAudioPlayer] = [
        .tick: makePlayer("rest_tick"),
        .finalTick: makePlayer("rest_tick_final"),
        .over: makePlayer("rest_over"),
    ].compactMapValues { $0 }
    private var stopDucking: Task<Void, Never>?

    func play(_ sound: RestSound) {
        duck(for: sound == .over ? Self.chimeDuck : Self.tickDuck)
        guard let player = players[sound] else { return }
        player.currentTime = 0
        player.play()
    }

    /// Keeps other audio lowered for [duration] from now; a later sound extends it.
    private func duck(for duration: Duration) {
        #if os(iOS)
        stopDucking?.cancel()
        let session = AVAudioSession.sharedInstance()
        do {
            try session.setCategory(.ambient, options: .duckOthers)
            try session.setActive(true)
        } catch {
            Self.logger.error("Audio session not started: \(error.localizedDescription, privacy: .public)")
        }
        stopDucking = Task {
            try? await Task.sleep(for: duration)
            guard !Task.isCancelled else { return }
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
        }
        #endif
    }

    private static func makePlayer(_ name: String) -> AVAudioPlayer? {
        guard let url = Bundle.main.url(forResource: name, withExtension: "wav"),
              let player = try? AVAudioPlayer(contentsOf: url) else {
            logger.error("Sound \(name, privacy: .public) not loaded")
            return nil
        }
        player.prepareToPlay()
        return player
    }
}

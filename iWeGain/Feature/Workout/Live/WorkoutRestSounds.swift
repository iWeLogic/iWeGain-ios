import Foundation

/// What a rest sounds like: the last seconds tick, 3, 2 and 1 higher, and a chime at the end.
nonisolated enum RestSound: Hashable, Sendable {
    case tick, finalTick, over

    private static let tickSeconds = 10
    private static let finalTickSeconds = 3

    /// The tick when the countdown on screen changes to [secondsLeft]; nil before the last seconds.
    static func tick(secondsLeft: Int) -> RestSound? {
        guard secondsLeft > 0, secondsLeft <= tickSeconds else { return nil }
        return secondsLeft <= finalTickSeconds ? .finalTick : .tick
    }
}

/// Ticks and chimes the running rest while the app is on screen (the sound part of Android's
/// `WorkoutNotificationManager`). A suspended app can't play anything: there the rest-over notification sounds.
final class WorkoutRestSounds {
    /// A chime later than this was missed while the app was suspended, and the notification already sounded.
    private static let chimeMargin: TimeInterval = 1
    /// How late a tick may be and still land when the number changes.
    private static let tickMargin: TimeInterval = 0.1

    private let workoutRepository: WorkoutRepository
    private let play: (RestSound) -> Void
    private let isAppActive: () -> Bool
    private let now: () -> Date
    private var observeTask: Task<Void, Never>?
    private var followTask: Task<Void, Never>?

    init(workoutRepository: WorkoutRepository, play: @escaping (RestSound) -> Void, isAppActive: @escaping () -> Bool, now: @escaping () -> Date) {
        self.workoutRepository = workoutRepository
        self.play = play
        self.isAppActive = isAppActive
        self.now = now
    }

    func start() {
        guard observeTask == nil else { return }
        observeTask = Task { [weak self, workoutRepository] in
            for await rest in workoutRepository.observeActiveWorkout().map({ $0?.rest }).removeDuplicates() {
                guard let self else { return }
                followTask?.cancel()
                followTask = rest.map { rest in Task { await self.follow(rest) } }
            }
        }
    }

    /// Counts [rest] down in step with the screen. Only a rest counted down here chimes: not one that was
    /// already over (the app started after it ended) or one that changed, which starts a new count.
    func follow(_ rest: RestTimer) async {
        guard !rest.isPaused else { return }
        var isFirstPass = true
        var lastTick: Int?
        while !Task.isCancelled {
            let remaining = rest.endsAt.timeIntervalSince(now())
            if remaining <= 0 {
                if !isFirstPass && -remaining < Self.chimeMargin && isAppActive() { play(.over) }
                return
            }
            let secondsLeft = Int(remaining.rounded(.up))
            let untilNextSecond = remaining.truncatingRemainder(dividingBy: 1)
            if !isFirstPass, secondsLeft != lastTick, untilNextSecond > 1 - Self.tickMargin, isAppActive(),
               let tick = RestSound.tick(secondsLeft: secondsLeft) {
                play(tick)
                lastTick = secondsLeft
            }
            isFirstPass = false
            // Wakes on each whole second before the end, so the ticks land when the number changes.
            try? await Task.sleep(for: .seconds(untilNextSecond == 0 ? 1 : untilNextSecond))
        }
    }
}

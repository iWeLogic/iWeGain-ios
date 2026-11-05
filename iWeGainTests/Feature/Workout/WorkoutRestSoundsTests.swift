import Foundation
import Testing
@testable import iWeGain

@MainActor
struct WorkoutRestSoundsTests {
    private let container = AppContainer.inMemory()

    private func rest(endingIn seconds: TimeInterval, paused: Bool = false) -> RestTimer {
        RestTimer(
            endsAt: Date().addingTimeInterval(seconds),
            durationSeconds: 60,
            savedExerciseIndex: 0,
            savedSetIndex: 0,
            pausedAt: paused ? Date() : nil
        )
    }

    /// Follows [rest] and returns what it played.
    private func played(following rest: RestTimer, isAppActive: Bool = true) async -> [RestSound] {
        var sounds: [RestSound] = []
        let follower = WorkoutRestSounds(
            workoutRepository: container.workoutRepository,
            play: { sounds.append($0) },
            isAppActive: { isAppActive },
            now: { Date() }
        )
        await follower.follow(rest)
        return sounds
    }

    @Test(arguments: [
        (11, RestSound?.none), (10, .tick), (4, .tick), (3, .finalTick), (1, .finalTick), (0, nil),
    ])
    func onlyTheLastSecondsTick(secondsLeft: Int, sound: RestSound?) {
        #expect(RestSound.tick(secondsLeft: secondsLeft) == sound)
    }

    @Test func aCountedRestChimesAtItsEnd() async {
        let sounds = await played(following: rest(endingIn: 0.3))
        #expect(sounds.last == .over)
    }

    @Test func aRestThatWasAlreadyOverStaysQuiet() async {
        #expect(await played(following: rest(endingIn: -0.2)).isEmpty)
    }

    @Test func aPausedRestStaysQuiet() async {
        #expect(await played(following: rest(endingIn: 0.3, paused: true)).isEmpty)
    }

    @Test func nothingPlaysWhileTheAppIsNotOnScreen() async {
        #expect(await played(following: rest(endingIn: 0.3), isAppActive: false).isEmpty)
    }
}

import Foundation
import Testing
@testable import iWeGain

/// What the Live Activity shows through a workout (Android's notification content), and its links.
@MainActor
struct WorkoutLiveStateTests {
    private let clock = TestClock()
    private let container: AppContainer
    private var repository: WorkoutRepository { container.workoutRepository }
    private let bench = BuiltInExercises.exercise(id: "bench_press")!

    init() throws {
        let clock = clock
        container = AppContainer.inMemory(now: { clock.now })
        try container.trainingRepository.saveTraining(Training(id: "t1", userId: User.guestId, name: "Push Day", icon: .dumbbell, exercises: [
            TrainingExercise(exercise: bench, sets: 2, restSeconds: 90),
        ]))
        try repository.startWorkout(try #require(container.trainingRepository.allTrainings().first))
    }

    private var state: WorkoutLiveState { repository.activeWorkout()!.liveState(unit: .kg, now: clock.now) }

    @Test func noExerciseRunningAsksToChooseOne() {
        #expect(state.kind == .chooseExercise)
        #expect(state.title == "Push Day")
        #expect(state.exerciseIndex == nil)
        #expect(state.countingRest == nil)
    }

    @Test func aRestCountsDownToTheNextSetAndGoesOverByItself() throws {
        try repository.startExercise(exerciseIndex: 0)
        clock.advance(30)

        #expect(state.kind == .rest)
        #expect(state.text == "Next: Barbell Bench Press · Set 1 of 2")
        #expect(state.countingRest == clock.now.addingTimeInterval(-30)...clock.now.addingTimeInterval(60))
        #expect(state.restExerciseIndex == 0)
        // Stale at the end of the rest: the widget shows what the app shows once it's over.
        let over = state.afterRest
        #expect(over.kind == .restOver)
        #expect(over.title == "Rest over")
        #expect(over.text == "Barbell Bench Press · Set 1 of 2 · 20 kg × 10")

        clock.advance(60)
        #expect(state.kind == .restOver)
        #expect(state.text == over.text)
    }

    @Test func aPausedRestStandsStill() throws {
        try repository.startExercise(exerciseIndex: 0)
        clock.advance(18)
        try repository.pauseRest()
        clock.advance(100)

        #expect(state.kind == .rest)
        #expect(state.restPausedSeconds == 72)
        #expect(state.title == "Rest paused · 1:12")
        #expect(state.countingRest == nil)
    }

    @Test func theNextSetIsDueWithoutARest() throws {
        try repository.startExercise(exerciseIndex: 0)
        try repository.endRest()

        #expect(state.kind == .set)
        #expect(state.exerciseIndex == 0)
        #expect(state.text == "Barbell Bench Press · Set 1 of 2 · 20 kg × 10")
    }

    @Test func theClockStopsOnceEverySetIsDone() throws {
        try repository.startExercise(exerciseIndex: 0)
        try repository.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 60, reps: 8)
        try repository.endRest()
        clock.advance(10)
        try repository.logSet(exerciseIndex: 0, setIndex: 1, weightKg: 60, reps: 8)
        clock.advance(300)

        #expect(state.kind == .allDone)
        #expect(state.stoppedElapsedSeconds == 10)
        #expect(state.doneSets == 2)
    }

    @Test(arguments: [
        (WorkoutLink.overview, "iwegain://workout"),
        (.exercise(index: 2, opensLogSet: false), "iwegain://workout/exercise/2"),
        (.exercise(index: 0, opensLogSet: true), "iwegain://workout/exercise/0/log-set"),
    ])
    func linksRoundTrip(link: WorkoutLink, url: String) throws {
        #expect(link.url.absoluteString == url)
        #expect(WorkoutLink(url: try #require(URL(string: url))) == link)
    }

    @Test(arguments: ["https://workout", "iwegain://training", "iwegain://workout/exercise", "iwegain://workout/exercise/x", "iwegain://workout/exercise/1/edit"])
    func otherLinksAreIgnored(url: String) throws {
        #expect(WorkoutLink(url: try #require(URL(string: url))) == nil)
    }
}

import Foundation
import Testing
@testable import iWeGain

struct WatchProtocolTests {
    private let state = WatchWorkoutState(
        isActive: true, exerciseIndex: 1, setIndex: 2, exerciseName: "Overhead Press", setCount: 3,
        targetWeightKg: 57.5, targetReps: 6, restFollows: true,
        restEndsAt: Date(timeIntervalSince1970: 1_000), restDurationSeconds: 120, restPausedRemaining: 42,
        allSetsDone: false, weightUnit: .lb
    )

    @Test func aStateSurvivesTheTrip() {
        let fields = state.dictionary(sentAt: Date(timeIntervalSince1970: 5))
        #expect(WatchWorkoutState(dictionary: fields) == state)
        #expect(WatchWorkoutState.sentAt(in: fields) == Date(timeIntervalSince1970: 5))
    }

    @Test func noneFieldsStayNone() {
        let none = WatchWorkoutState(isActive: false)
        #expect(WatchWorkoutState(dictionary: none.dictionary(sentAt: Date())) == none)
    }

    @Test func anEmptyContextIsNoState() {
        #expect(WatchWorkoutState(dictionary: [:]) == nil)
    }

    @Test(arguments: [
        WatchCommand.logSet(exerciseIndex: 1, setIndex: 2, weightKg: 57.5, reps: 8),
        .adjustRest(deltaSeconds: -15),
        .requestState,
    ])
    func commandsSurviveTheTrip(command: WatchCommand) {
        #expect(WatchCommand(dictionary: command.dictionary) == command)
    }

    @Test func invalidCommandsAreRejected() {
        var negativeWeight = WatchCommand.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 1, reps: 1).dictionary
        negativeWeight["weightKg"] = -1.0
        var noReps = WatchCommand.logSet(exerciseIndex: 0, setIndex: 0, weightKg: 1, reps: 1).dictionary
        noReps["reps"] = 0
        #expect(WatchCommand(dictionary: negativeWeight) == nil)
        #expect(WatchCommand(dictionary: noReps) == nil)
        #expect(WatchCommand(dictionary: WatchCommand.adjustRest(deltaSeconds: 0).dictionary) == nil)
        #expect(WatchCommand(dictionary: ["path": "/other"]) == nil)
        #expect(WatchCommand(dictionary: [:]) == nil)
    }

    @Test func restTimeCountsDownOrStandsStill() {
        let now = Date(timeIntervalSince1970: 990)
        var counting = state
        counting.restPausedRemaining = nil
        #expect(counting.restRemaining(now: now) == 10)
        #expect(counting.countingRestEnd == counting.restEndsAt)
        #expect(state.restRemaining(now: now) == 42)
        #expect(state.countingRestEnd == nil)
        #expect(counting.isRestOver(now: Date(timeIntervalSince1970: 1_001)))
        #expect(!WatchWorkoutState(isActive: true).isRestOver(now: now))
    }

    // MARK: Log Set

    @Test func logSetStartsAtTheTargetInTheUnit() throws {
        let logSet = try #require(WatchLogSet(workout: WatchWorkoutState(
            isActive: true, exerciseIndex: 0, setIndex: 1, targetWeightKg: 57.5, targetReps: 8, weightUnit: .lb
        )))
        #expect(logSet.weightText == "126.8")
        #expect(logSet.reps == 8)
        #expect(logSet.setNumber == 2)
    }

    @Test func logSetNeedsADueSet() {
        #expect(WatchLogSet(workout: WatchWorkoutState(isActive: true)) == nil)
    }

    @Test func stepsStopAtTheirLimitsAndDontDrift() throws {
        var logSet = try #require(WatchLogSet(workout: WatchWorkoutState(
            isActive: true, exerciseIndex: 0, setIndex: 0, targetWeightKg: 0.25, targetReps: 2
        )))
        logSet.changeWeight(steps: -1)
        #expect(!logSet.canDecreaseWeight)
        logSet.changeWeight(steps: -1)
        #expect(logSet.weightText == "0")
        logSet.changeReps(delta: -1)
        #expect(!logSet.canDecreaseReps)
        logSet.changeReps(delta: -1)
        #expect(logSet.reps == 1)

        var pounds = try #require(WatchLogSet(workout: WatchWorkoutState(
            isActive: true, exerciseIndex: 0, setIndex: 0, targetWeightKg: 57.5, targetReps: 8, weightUnit: .lb
        )))
        for _ in 0..<10 { pounds.changeWeight(steps: 1) }
        #expect(pounds.weightText == "131.8")
    }

    @Test func logSetGoesOutOfDateWithTheSet() throws {
        let workout = WatchWorkoutState(isActive: true, exerciseIndex: 0, setIndex: 0, targetWeightKg: 10, targetReps: 5)
        let logSet = try #require(WatchLogSet(workout: workout))
        #expect(!logSet.isOutOfDate(for: workout))
        var nextSet = workout
        nextSet.setIndex = 1
        #expect(logSet.isOutOfDate(for: nextSet))
        #expect(logSet.isOutOfDate(for: WatchWorkoutState(isActive: false)))
    }

    @Test func savingSendsKilograms() throws {
        let logSet = try #require(WatchLogSet(workout: WatchWorkoutState(
            isActive: true, exerciseIndex: 1, setIndex: 0, targetWeightKg: 50, targetReps: 5, weightUnit: .kg
        )))
        #expect(logSet.command == .logSet(exerciseIndex: 1, setIndex: 0, weightKg: 50, reps: 5))
    }
}

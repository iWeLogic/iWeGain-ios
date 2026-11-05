#if DEBUG
import Foundation

/// Debug-only launch arguments for screenshots and manual testing:
/// `-seed-sample-data` adds sample trainings to an empty database;
/// `-debug-route <route>` opens a screen: `design-catalog`, `new-training`, `first-training`, `exercise-library`, `workout` (starts the first training), `workout-exercise` (and its first exercise), `free-workout`, `calendar`, `schedule` (a new plan for today), `workout-details` (the latest finished workout), `edit-workout` (and its editor).
enum DebugLaunch {
    static var arguments: [String] { ProcessInfo.processInfo.arguments }

    static var route: String? {
        guard let index = arguments.firstIndex(of: "-debug-route"), index + 1 < arguments.count else { return nil }
        return arguments[index + 1]
    }

    static func seedIfRequested(_ container: AppContainer) {
        guard arguments.contains("-seed-sample-data"), (try? container.trainingRepository.allTrainings().isEmpty) == true else { return }
        let userId = container.userRepository.selectedUserId
        func entry(_ id: String, sets: Int, rest: Int) -> TrainingExercise {
            TrainingExercise(exercise: BuiltInExercises.exercise(id: id)!, sets: sets, restSeconds: rest)
        }
        let trainings = [
            Training(id: "sample-push", userId: userId, name: "Push Day", icon: .dumbbell, exercises: [
                entry("bench_press", sets: 4, rest: 120), entry("overhead_press", sets: 3, rest: 90),
                entry("incline_dumbbell_press", sets: 3, rest: 90), entry("triceps_pushdown", sets: 3, rest: 60),
            ]),
            Training(id: "sample-pull", userId: userId, name: "Pull Day", icon: .zap, exercises: [
                entry("pull_up", sets: 4, rest: 120), entry("barbell_row", sets: 4, rest: 90), entry("barbell_curl", sets: 3, rest: 60),
            ]),
            Training(id: "sample-legs", userId: userId, name: "Leg Day", icon: .mountain, exercises: [
                entry("back_squat", sets: 5, rest: 180), entry("romanian_deadlift", sets: 3, rest: 120),
                entry("leg_press", sets: 3, rest: 90), entry("calf_raise", sets: 4, rest: 60),
            ]),
        ]
        trainings.forEach { try? container.trainingRepository.saveTraining($0) }
        seedHistory(container, userId: userId, push: trainings[0])
    }

    /// Two finished Push Day workouts (two days and a week before) and Pull Day planned every week from tomorrow.
    private static func seedHistory(_ container: AppContainer, userId: String, push: Training) {
        let now = container.store.now()
        let today = Day(now)
        for (index, daysAgo) in [9, 2].enumerated() {
            let startedAt = today.adding(days: -daysAgo).date(at: TimeOfDay(hour: 18, minute: 5))
            let exercises = push.exercises.map { entry in
                let weight = 40.0 + Double(entry.restSeconds / 3) + Double(index) * 2.5
                return WorkoutExercise(
                    exercise: entry.exercise, restSeconds: entry.restSeconds,
                    sets: (0..<entry.sets).map { set in
                        set == entry.sets - 1 && index == 0
                            ? WorkoutSet(status: .skipped, targetWeightKg: weight, targetReps: 8)
                            : WorkoutSet(status: .done, targetWeightKg: weight, targetReps: 8, weightKg: weight, reps: 10 - set)
                    },
                    startedAt: startedAt
                )
            }
            try? WorkoutLocalDataSource(store: container.store).save(Workout(
                id: "sample-workout-\(index)", userId: userId, trainingId: push.id, trainingName: push.name, trainingIcon: push.icon,
                startedAt: startedAt, finishedAt: startedAt.addingTimeInterval(TimeInterval((68 + index * 4) * 60)), exercises: exercises
            ))
        }
        try? container.scheduleRepository.schedule(
            userId: userId, trainingId: "sample-pull", date: today.adding(days: 1),
            startTime: TimeOfDay(hour: 18, minute: 0), endTime: TimeOfDay(hour: 19, minute: 0), repeatsWeekly: true
        )
    }
}
#endif

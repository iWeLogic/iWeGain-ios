#if os(iOS)
import ActivityKit
import AppIntents

/// The running workout's Live Activity; one per workout.
nonisolated struct WorkoutActivityAttributes: ActivityAttributes {
    typealias ContentState = WorkoutLiveState

    let workoutId: String
}

/// What the Live Activity's buttons do. The app sets [handler] when it starts; the intents run in the
/// app's process (`LiveActivityIntent`, the app is launched in the background if needed), so the widget
/// extension never calls it.
@MainActor
enum WorkoutLiveActions {
    nonisolated enum Action: Sendable {
        /// +15 s of rest, or a new 15 s rest once it's over.
        case addRest
        case skipSet
        case skipRest
    }

    static var handler: ((Action) async -> Void)?

    static func run(_ action: Action) async {
        await handler?(action)
    }
}

struct AddRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "workout_notification_add_rest"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActions.run(.addRest)
        return .result()
    }
}

struct SkipSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "workout_notification_skip_set"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActions.run(.skipSet)
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "workout_notification_skip_rest"
    static let isDiscoverable = false

    func perform() async throws -> some IntentResult {
        await WorkoutLiveActions.run(.skipRest)
        return .result()
    }
}
#endif

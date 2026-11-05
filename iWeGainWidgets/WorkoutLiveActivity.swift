import ActivityKit
import AppIntents
import SwiftUI
import WidgetKit

/// The running workout on the Lock Screen and in the Dynamic Island: the current set, the rest
/// countdown or what's next, with the buttons of Android's workout notification.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(state: context.displayed)
                .activityBackgroundTint(Color.bgSurface)
                .activitySystemActionForegroundColor(Color.accentPrimary)
                .widgetURL(context.displayed.openLink.url)
        } dynamicIsland: { context in
            let state = context.displayed
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Label { Text(state.trainingName).lineLimit(1) } icon: { AppIcon("ic_dumbbell", size: 16) }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentPrimary)
                        .padding(.leading, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TimerText(state: state)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(state.kind == .rest ? Color.accentPrimary : .white)
                        .padding(.trailing, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 8) {
                        Details(state: state, primary: .white, secondary: .white.opacity(0.6))
                        StateProgress(state: state)
                        Actions(state: state)
                    }
                    .padding(.horizontal, 4)
                }
            } compactLeading: {
                AppIcon(state.kind == .rest ? "ic_timer" : "ic_dumbbell", size: 18)
                    .foregroundStyle(Color.accentPrimary)
            } compactTrailing: {
                TimerText(state: state)
                    .frame(maxWidth: 52)
                    .foregroundStyle(state.kind == .rest ? Color.accentPrimary : .white)
            } minimal: {
                if let range = state.countingRest {
                    ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                        .progressViewStyle(.circular)
                        .tint(Color.accentPrimary)
                } else {
                    AppIcon("ic_dumbbell", size: 16).foregroundStyle(Color.accentPrimary)
                }
            }
            .widgetURL(state.openLink.url)
            .keylineTint(Color.accentPrimary)
        }
    }
}

private extension ActivityViewContext<WorkoutActivityAttributes> {
    /// The rest is over once the activity goes stale at its end, even when the app couldn't update it.
    var displayed: WorkoutLiveState { isStale ? state.afterRest : state }
}

private extension WorkoutLiveState {
    /// A tap opens the screen the activity is about: the resting or running exercise, or the overview.
    var openLink: WorkoutLink {
        if kind == .rest, let restExerciseIndex { return .exercise(index: restExerciseIndex, opensLogSet: false) }
        if let exerciseIndex { return .exercise(index: exerciseIndex, opensLogSet: false) }
        return .overview
    }
}

private struct LockScreenView: View {
    let state: WorkoutLiveState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                AppIcon("ic_dumbbell", size: 14)
                    .foregroundStyle(Color.accentOn)
                    .frame(width: 24, height: 24)
                    .background(Color.accentPrimary, in: .circle)
                Text(state.trainingName)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Color.textSecondary)
                    .lineLimit(1)
                Spacer(minLength: 8)
                TimerText(state: state)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(state.kind == .rest ? Color.accentPrimary : Color.textPrimary)
                    .frame(maxWidth: 110, alignment: .trailing)
            }
            Details(state: state, primary: Color.textPrimary, secondary: Color.textSecondary)
            StateProgress(state: state)
            Actions(state: state)
        }
        .padding(16)
    }
}

/// The title and the line under it.
private struct Details: View {
    let state: WorkoutLiveState
    let primary: Color
    let secondary: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // While a set is due the training name is already in the header.
            if state.kind != .set && state.kind != .chooseExercise && state.kind != .allDone {
                Text(state.title)
                    .font(.headline)
                    .foregroundStyle(primary)
                    .lineLimit(1)
            }
            Text(state.text)
                .font(state.kind == .set ? .headline : .subheadline)
                .foregroundStyle(state.kind == .set ? primary : secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The rest countdown, a paused rest's time left, or the workout clock.
private struct TimerText: View {
    let state: WorkoutLiveState

    var body: some View {
        Group {
            if let range = state.countingRest {
                Text(timerInterval: range, countsDown: true)
            } else if state.kind == .rest, let paused = state.restPausedSeconds {
                Text(WorkoutLiveState.clock(paused))
            } else if state.kind == .restOver {
                Text(verbatim: "0:00")
            } else if let stopped = state.stoppedElapsedSeconds {
                Text(WorkoutLiveState.clock(stopped))
            } else {
                Text(state.startedAt, style: .timer)
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
        .lineLimit(1)
    }
}

/// The rest draining, like the ring on the exercise screen, or the workout's sets.
private struct StateProgress: View {
    let state: WorkoutLiveState

    var body: some View {
        Group {
            if let range = state.countingRest {
                ProgressView(timerInterval: range, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
            } else if state.kind == .restOver {
                ProgressView(value: 0)
            } else if state.kind == .rest, let paused = state.restPausedSeconds, let duration = state.restDurationSeconds, duration > 0 {
                // Paused: stands still where it stopped.
                ProgressView(value: min(1, Double(paused) / Double(duration)))
            } else {
                ProgressView(value: Double(state.doneSets), total: Double(max(1, state.totalSets)))
            }
        }
        .progressViewStyle(.linear)
        .tint(Color.accentPrimary)
    }
}

private struct Actions: View {
    let state: WorkoutLiveState

    var body: some View {
        switch state.kind {
        case .set, .restOver:
            HStack(spacing: 8) {
                if let index = state.exerciseIndex {
                    Link(destination: WorkoutLink.exercise(index: index, opensLogSet: true).url) {
                        ActionLabel(title: state.labels.complete, icon: "ic_check", isPrimary: true)
                    }
                }
                Button(intent: AddRestIntent()) { ActionLabel(title: state.labels.addRest, icon: "ic_plus") }
                    .buttonStyle(.plain)
                Button(intent: SkipSetIntent()) { ActionLabel(title: state.labels.skipSet, icon: "ic_skip_forward") }
                    .buttonStyle(.plain)
            }
        case .rest:
            HStack(spacing: 8) {
                Button(intent: AddRestIntent()) { ActionLabel(title: state.labels.addRest, icon: "ic_plus") }
                    .buttonStyle(.plain)
                Button(intent: SkipRestIntent()) { ActionLabel(title: state.labels.skipRest, icon: "ic_skip_forward") }
                    .buttonStyle(.plain)
            }
        case .chooseExercise, .allDone:
            EmptyView()
        }
    }
}

private struct ActionLabel: View {
    let title: String
    let icon: String
    var isPrimary = false

    var body: some View {
        HStack(spacing: 4) {
            AppIcon(icon, size: 14)
            Text(title).lineLimit(1).minimumScaleFactor(0.8)
        }
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(isPrimary ? Color.accentOn : Color.textPrimary)
        .frame(maxWidth: .infinity, minHeight: 36)
        .background(isPrimary ? Color.accentPrimary : Color.bgSurface2, in: .capsule)
    }
}

/// An icon from the asset catalog (the Android vector icons), tinted with the foreground style.
private struct AppIcon: View {
    let name: String
    let size: CGFloat

    init(_ name: String, size: CGFloat) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image(name).renderingMode(.template).resizable().frame(width: size, height: size)
    }
}

#Preview("Set", as: .content, using: WorkoutActivityAttributes(workoutId: "1")) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutLiveState.preview(kind: .set)
    WorkoutLiveState.preview(kind: .rest)
    WorkoutLiveState.preview(kind: .chooseExercise)
}

#Preview("Dynamic Island", as: .dynamicIsland(.expanded), using: WorkoutActivityAttributes(workoutId: "1")) {
    WorkoutLiveActivity()
} contentStates: {
    WorkoutLiveState.preview(kind: .rest)
    WorkoutLiveState.preview(kind: .set)
}

private extension WorkoutLiveState {
    static func preview(kind: Kind) -> WorkoutLiveState {
        let isRest = kind == .rest
        let text = switch kind {
        case .rest: "Next: Bench Press · Set 3 of 4"
        case .chooseExercise: "Choose the next exercise · 4 / 13 sets"
        default: "Bench Press · Set 3 of 4 · 60 kg × 8"
        }
        return WorkoutLiveState(
            kind: kind,
            trainingName: "Push Day",
            title: isRest ? "Rest" : "Push Day",
            text: text,
            restOverText: "Bench Press · Set 3 of 4 · 60 kg × 8",
            startedAt: .now.addingTimeInterval(-1_450),
            doneSets: 4,
            totalSets: 13,
            exerciseIndex: kind == .chooseExercise ? nil : 0,
            restExerciseIndex: isRest ? 0 : nil,
            restEndsAt: isRest ? .now.addingTimeInterval(84) : nil,
            restDurationSeconds: isRest ? 120 : nil,
            labels: Labels(complete: "Complete", skipSet: "Skip", addRest: "+15 s", skipRest: "Skip rest", restOver: "Rest over")
        )
    }
}

import SwiftUI

/// Figma "Watch · Wear OS" (51–55), fitted to Apple Watch's rectangular screen.
struct WatchWorkoutScreen: View {
    let state: WatchWorkoutUiState
    let onAction: (WatchWorkoutAction) -> Void

    var body: some View {
        GeometryReader { geometry in
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .environment(\.watchScale, geometry.size.width / WatchScale.designWidth)
        }
        .background(Color.watchBgBase.ignoresSafeArea())
        .sheet(isPresented: isLogSetOpen) {
            if let logSet = state.logSet {
                GeometryReader { geometry in
                    WatchLogSetContent(logSet: logSet, canSave: state.isPhoneConnected, onAction: onAction)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .environment(\.watchScale, geometry.size.width / WatchScale.designWidth)
                }
                .containerBackground(Color.watchBgBase, for: .navigation)
            }
        }
    }

    private var isLogSetOpen: Binding<Bool> {
        Binding(get: { state.logSet != nil }, set: { if !$0 { onAction(.onLogSetDismiss) } })
    }

    @ViewBuilder
    private var content: some View {
        if !state.isPhoneConnected {
            NotConnectedContent(workout: state.workout)
        } else if let workout = state.workout {
            if !workout.isActive {
                MessageContent(title: "no_workout_title", message: "no_workout_message")
            } else if workout.setIndex == nil {
                MessageContent(
                    title: workout.allSetsDone ? "all_done_title" : "choose_exercise_title",
                    message: workout.allSetsDone ? "all_done_message" : "choose_exercise_message"
                )
            } else {
                SetContent(workout: workout, onAction: onAction)
            }
        }
    }
}

/// The due set, with the rest before it: "51 · Watch · Rest" (the ring drains with the countdown, which the
/// watch runs from the end time the phone sent) and "52 · Watch · Rest Over" (only the gray track is left).
/// Without a rest, the set.
private struct SetContent: View {
    let workout: WatchWorkoutState
    let onAction: (WatchWorkoutAction) -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { context in
            let remaining = workout.restRemaining(now: context.date)
            let isResting = workout.hasRest && remaining > 0
            ZStack {
                if workout.hasRest { RestRing(progress: isResting ? remaining / Double(max(workout.restDurationSeconds, 1)) : 0) }
                if isResting {
                    resting(remaining: remaining)
                } else if workout.isRestOver(now: context.date) {
                    restOver
                } else {
                    set
                }
            }
        }
    }

    private func resting(remaining: TimeInterval) -> some View {
        VStack(spacing: 6) {
            if let target = workout.targetText {
                Text(Strings.format("next_set", target)).watchText(14).lineLimit(1).minimumScaleFactor(0.7)
            }
            RestTimerRow(
                time: Durations.clock(remaining.rounded(.up)),
                canShorten: true,
                isPaused: workout.restPausedRemaining != nil,
                onAction: onAction
            )
            RestTotal(durationSeconds: workout.restDurationSeconds)
            WatchPillButton(title: "complete", kind: .secondary) { onAction(.onCompleteTap) }
        }
        .padding(.horizontal, 10)
    }

    private var restOver: some View {
        VStack(spacing: 6) {
            if let target = workout.targetText {
                Text(target).watchText(15, .semiBold).lineLimit(1).minimumScaleFactor(0.7)
            }
            // −15 s has nothing left to take; +15 s starts a short extra rest, as on the phone.
            RestTimerRow(time: Durations.clock(0), canShorten: false, isPaused: false, onAction: onAction)
            RestTotal(durationSeconds: workout.restDurationSeconds)
            WatchPillButton(title: "complete") { onAction(.onCompleteTap) }
        }
        .padding(.horizontal, 10)
    }

    private var set: some View {
        VStack(spacing: 4) {
            Text(workout.exerciseName).watchText(14, .medium, color: .watchTextSecondary).lineLimit(1).minimumScaleFactor(0.7)
            if let target = workout.targetText {
                Text(target).watchText(26, .bold).lineLimit(1).minimumScaleFactor(0.6)
            }
            if let setNumber = workout.setNumber {
                Text(Strings.format("set_of", setNumber, workout.setCount)).watchText(14, color: .watchTextSecondary)
            }
            WatchPillButton(title: "complete") { onAction(.onCompleteTap) }.padding(.top, 8)
        }
        .padding(.horizontal, 10)
    }
}

/// The rest time between −15 s and +15 s, like the phone's rest card.
private struct RestTimerRow: View {
    private static let stepSeconds = 15

    let time: String
    let canShorten: Bool
    let isPaused: Bool
    let onAction: (WatchWorkoutAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            WatchRoundButton(accessibilityText: Text("rest_minus_description"), isEnabled: canShorten) {
                onAction(.onAdjustRestTap(deltaSeconds: -Self.stepSeconds))
            } label: {
                Text("rest_minus").watchText(12, .semiBold, color: canShorten ? .watchTextPrimary : .watchTextTertiary)
            }
            // A paused rest stands still in gray.
            Text(time)
                .watchText(32, .bold, color: isPaused ? .watchTextSecondary : .watchTextPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .frame(maxWidth: .infinity)
            WatchRoundButton(accessibilityText: Text("rest_plus_description")) {
                onAction(.onAdjustRestTap(deltaSeconds: Self.stepSeconds))
            } label: {
                Text("rest_plus").watchText(12, .semiBold)
            }
        }
    }
}

/// "of 2:00": the whole rest, +15 / −15 included, under the countdown.
private struct RestTotal: View {
    let durationSeconds: Int

    var body: some View {
        if durationSeconds > 0 {
            Text(Strings.format("rest_total", Durations.clock(TimeInterval(durationSeconds)))).watchText(13, color: .watchTextSecondary)
        }
    }
}

private struct RestRing: View {
    private static let lineWidth: CGFloat = 4
    /// Close to the corners of the current Apple Watch screens.
    private static let cornerRadius: CGFloat = 40

    let progress: Double

    var body: some View {
        let shape = RestEdgeShape(cornerRadius: Self.cornerRadius)
        ZStack {
            shape.stroke(Color.watchBorder, lineWidth: Self.lineWidth)
            shape.trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(Color.watchAccent, style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round))
                .animation(.linear(duration: 0.25), value: progress)
        }
        .padding(Self.lineWidth / 2)
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// "53 · Watch · Phone Not Connected": the last state stays, commands are off.
private struct NotConnectedContent: View {
    let workout: WatchWorkoutState?

    var body: some View {
        VStack(spacing: 4) {
            WatchIcon(name: "ic_cloud_off", size: 24)
            Text("not_connected_title").watchText(15, .semiBold).multilineTextAlignment(.center)
            Text("not_connected_message").watchText(13, color: .watchTextSecondary).multilineTextAlignment(.center)
            if let workout, workout.isActive, let setNumber = workout.setNumber {
                Text(Strings.format("exercise_set", workout.exerciseName, setNumber, workout.setCount))
                    .watchText(12, color: .watchTextTertiary)
                    .lineLimit(1)
                    .padding(.top, 4)
                WatchPillButton(title: "complete", kind: .disabled) {}.padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
    }
}

/// "54 · Watch · No Workout", and the same for "choose the next exercise" and "all sets done". There's no
/// "Open on phone" here: watchOS can't bring the phone app up.
private struct MessageContent: View {
    let title: LocalizedStringKey
    let message: LocalizedStringKey

    var body: some View {
        VStack(spacing: 6) {
            WatchIcon(name: "ic_dumbbell", size: 28)
            Text(title).watchText(16, .semiBold).multilineTextAlignment(.center)
            Text(message).watchText(14, color: .watchTextSecondary).multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
    }
}

extension WatchWorkoutState {
    /// "60 kg × 6", or nil without a target.
    var targetText: String? {
        guard let targetWeightKg, let targetReps else { return nil }
        return Strings.format(weightUnit == .kg ? "set_result_kg" : "set_result_lb", weightUnit.weightNumber(targetWeightKg), targetReps)
    }
}

enum Strings {
    static func format(_ key: String.LocalizationValue, _ arguments: CVarArg...) -> String {
        String(format: String(localized: key), arguments: arguments)
    }
}

enum Durations {
    /// "1:24", "12:05".
    static func clock(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

#if DEBUG
#Preview("Rest") {
    WatchWorkoutScreen(
        state: WatchWorkoutUiState(
            workout: WatchWorkoutState(
                isActive: true, exerciseIndex: 1, setIndex: 2, exerciseName: "Overhead Press", setCount: 3,
                targetWeightKg: 60, targetReps: 6, restEndsAt: Date().addingTimeInterval(84), restDurationSeconds: 120
            )
        ),
        onAction: { _ in }
    )
}
#endif

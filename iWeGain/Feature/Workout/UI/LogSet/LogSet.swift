import Foundation

/// The Log Set sheet (Figma "14 · Log Set"): weight and reps with an in-app keypad.
struct LogSetUi: Equatable {
    var setNumber: Int
    var exerciseName: String
    /// "Weight, kg".
    var weightLabel: String
    /// As typed, in the user's weight unit: "57.5".
    var weight: String
    var reps: String
    var weightHint: String?
    var repsHint: String?
    var focused: LogSetField?
    /// The next key press replaces the value instead of appending to it (just after focusing).
    var replaceOnType = false
    /// Saving starts a rest timer ("Save & start rest") rather than just saving.
    var startsRest = false
    /// Changing a set that's already logged ("Edit set 1", "Save"), rather than logging the current one.
    var isEdit = false
    /// Edit workout: whether the set was done (true) or skipped (false), with a switch between them;
    /// nil hides the switch (logging a set during a workout).
    var isDone: Bool?
    /// Shows the trash button that deletes the set (free workouts).
    var canDelete = false
    var canSave = true

    var title: String { Strings.format(isEdit ? "log_set_edit_title" : "log_set_title", setNumber) }

    var saveTitle: String {
        Strings.text(isEdit ? "log_set_save_edit" : startsRest ? "log_set_save_rest" : "log_set_save")
    }
}

enum LogSetField: Equatable {
    case weight, reps
}

enum LogSetAction: Equatable {
    case onFieldTap(LogSetField)
    case onWeightDecrease
    case onWeightIncrease
    case onRepsDecrease
    case onRepsIncrease
    case onKey(Character)
    case onBackspace
    /// Edit workout: done or skipped.
    case onStatusChange(isDone: Bool)
    case onSave
    case onDelete
    case onDismiss
}

extension LogSetUi {
    static let maxWeightLength = 6
    static let maxDecimals = 2
    static let maxWeight = 9999.0
    static let maxRepsLength = 3
    static let maxReps = 999

    /// Applies an input action (typing, the steppers) to the sheet; [weightStep] is one step of the
    /// weight stepper in the user's unit. Save, Delete and Dismiss are up to the screen.
    func reduce(_ action: LogSetAction, weightStep: Double) -> LogSetUi {
        var updated = self
        switch action {
        case .onFieldTap(let field):
            if focused == field {
                updated.focused = nil
                updated.replaceOnType = false
            } else {
                updated.focused = field
                updated.replaceOnType = true
            }
        case .onWeightDecrease:
            updated.weight = Self.stepWeight(weight, by: -weightStep)
            updated.replaceOnType = false
        case .onWeightIncrease:
            updated.weight = Self.stepWeight(weight, by: weightStep)
            updated.replaceOnType = false
        case .onRepsDecrease:
            updated.reps = Self.stepReps(reps, by: -1)
            updated.replaceOnType = false
        case .onRepsIncrease:
            updated.reps = Self.stepReps(reps, by: 1)
            updated.replaceOnType = false
        case .onKey(let key): updated = type(key)
        case .onBackspace:
            switch focused {
            case .weight: updated.weight = String(weight.dropLast())
            case .reps: updated.reps = String(reps.dropLast())
            case nil: break
            }
            updated.replaceOnType = false
        case .onStatusChange(let isDone):
            updated.isDone = isDone
            updated.focused = nil
            updated.replaceOnType = false
        case .onSave, .onDelete, .onDismiss: break
        }
        // A skipped set keeps no reps, so there's nothing to check.
        updated.canSave = updated.isDone == false || (Int(updated.reps) ?? 0) > 0
        return updated
    }

    private func type(_ key: Character) -> LogSetUi {
        guard let field = focused else { return self }
        let current = replaceOnType ? "" : field == .weight ? weight : reps
        let typed: String
        if field == .reps {
            typed = key.isWholeNumber && current.count < Self.maxRepsLength ? Self.trimmingLeadingZeros(current + String(key)) : current
        } else if key == "." {
            typed = current.contains(".") || current.count >= Self.maxWeightLength ? current : (current.isEmpty ? "0" : current) + "."
        } else if !key.isWholeNumber {
            typed = current
        } else if let dot = current.firstIndex(of: "."), current[current.index(after: dot)...].count >= Self.maxDecimals {
            typed = current
        } else if current.count >= Self.maxWeightLength {
            typed = current
        } else if current == "0" {
            typed = String(key)
        } else {
            typed = current + String(key)
        }
        var updated = self
        if field == .weight { updated.weight = typed } else { updated.reps = typed }
        updated.replaceOnType = false
        return updated
    }

    private static func trimmingLeadingZeros(_ text: String) -> String {
        String(text.drop { $0 == "0" })
    }

    private static func stepWeight(_ weight: String, by delta: Double) -> String {
        Weights.number(min(maxWeight, max(0, (Double(weight) ?? 0) + delta)))
    }

    private static func stepReps(_ reps: String, by delta: Int) -> String {
        String(min(maxReps, max(1, (Int(reps) ?? 0) + delta)))
    }
}

import Foundation

nonisolated enum Durations {
    /// Rest duration label: "90 s" under two minutes, then "2 min" or "2:30".
    static func rest(_ seconds: Int) -> String {
        if seconds < 120 { return Strings.format("duration_seconds", seconds) }
        if seconds % 60 == 0 { return Strings.format("duration_minutes", seconds / 60) }
        return Strings.format("duration_minutes_seconds", seconds / 60, seconds % 60)
    }

    /// Clock-style duration: "1:24", "24:13", or "1:04:13" from an hour on.
    static func clock(_ totalSeconds: Int) -> String {
        let seconds = max(0, totalSeconds)
        let hours = seconds / 3600, minutes = seconds % 3600 / 60, secs = seconds % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }

    /// Workout length: "45 min", "2 h" or "1 h 12 min".
    static func workout(minutes: Int) -> String {
        let hours = minutes / 60, rest = minutes % 60
        if hours == 0 { return Strings.format("duration_minutes", rest) }
        if rest == 0 { return Strings.format("duration_hours", hours) }
        return Strings.format("duration_hours_minutes", hours, rest)
    }
}

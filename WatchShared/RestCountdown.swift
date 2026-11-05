import Foundation

/// Follows a running rest in step with the number on screen, for the phone's sounds and the watch's buzzes.
enum RestCountdown {
    /// An end later than this was missed while the app was suspended, so it isn't announced any more.
    private static let overMargin: TimeInterval = 1
    /// How late a second may be and still land when the number changes.
    private static let secondMargin: TimeInterval = 0.1

    /// Calls [onSecond] with the seconds left each time the number changes, then [onOver] at the end. Only a
    /// rest counted down here ends with [onOver]: not one that was already over when this started.
    static func run(endsAt: Date, now: () -> Date, onSecond: (Int) -> Void, onOver: () -> Void) async {
        var isFirstPass = true
        var lastSecond: Int?
        while !Task.isCancelled {
            let remaining = endsAt.timeIntervalSince(now())
            if remaining <= 0 {
                if !isFirstPass && -remaining < overMargin { onOver() }
                return
            }
            let secondsLeft = Int(remaining.rounded(.up))
            let untilNextSecond = remaining.truncatingRemainder(dividingBy: 1)
            if !isFirstPass, secondsLeft != lastSecond, untilNextSecond > 1 - secondMargin {
                onSecond(secondsLeft)
                lastSecond = secondsLeft
            }
            isFirstPass = false
            try? await Task.sleep(for: .seconds(untilNextSecond == 0 ? 1 : untilNextSecond))
        }
    }
}

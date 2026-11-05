import Foundation

/// Emits [now] right away and then every [period], for the workout clock and rest countdowns
/// (Android's `tickerFlow`). It stops when the consuming task is cancelled.
func ticker(every period: Duration = .seconds(1), now: @escaping () -> Date) -> AsyncStream<Date> {
    AsyncStream { continuation in
        let task = Task { @MainActor in
            while !Task.isCancelled {
                continuation.yield(now())
                try? await Task.sleep(for: period)
            }
            continuation.finish()
        }
        continuation.onTermination = { _ in task.cancel() }
    }
}

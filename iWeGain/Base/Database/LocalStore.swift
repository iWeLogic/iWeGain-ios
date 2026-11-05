import Foundation
import SwiftData

/// The app's SwiftData context plus a change signal: every save through [save] tells the
/// [changes] streams, so screens follow the data like Room's Flows on Android. All local data sources
/// share one instance (`AppContainer.store`).
final class LocalStore {
    /// Kept alive as long as the store: a context whose container is gone crashes on its next fetch.
    let container: ModelContainer
    let context: ModelContext
    /// The current time; tests pass a fixed clock.
    let now: () -> Date

    private var continuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    init(container: ModelContainer, now: @escaping () -> Date = { Date() }) {
        self.container = container
        context = container.mainContext
        // Saves happen explicitly through save(), so observers hear about every change.
        context.autosaveEnabled = false
        self.now = now
    }

    func save() throws {
        if context.hasChanges { try context.save() }
        notifyChanged()
    }

    /// Emits once right away and again after every save.
    func changes() -> AsyncStream<Void> {
        let (stream, continuation) = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        let id = UUID()
        continuations[id] = continuation
        continuation.yield()
        continuation.onTermination = { [weak self] _ in
            Task { @MainActor in self?.continuations[id] = nil }
        }
        return stream
    }

    /// Tells the observers without a database save, for data kept elsewhere (settings, the selected person).
    func notifyChanged() {
        continuations.values.forEach { $0.yield() }
    }
}

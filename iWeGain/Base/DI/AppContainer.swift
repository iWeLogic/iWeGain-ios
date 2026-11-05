import Foundation
import SwiftData

/// Composition root: owns the shared infrastructure. Each feature adds its repositories and
/// ViewModel factories in an extension (`Feature/<Name>/Data/<Name>Module.swift`).
final class AppContainer {
    let modelContainer: ModelContainer
    let defaults: UserDefaults
    /// The one SwiftData context and its change signal, shared by every local data source.
    let store: LocalStore
    let firestore = FirestoreProvider()
    let network = NetworkMonitor()
    private var singletons: [ObjectIdentifier: AnyObject] = [:]

    init(modelContainer: ModelContainer, defaults: UserDefaults = .standard, now: @escaping () -> Date = { Date() }) {
        self.modelContainer = modelContainer
        self.defaults = defaults
        store = LocalStore(container: modelContainer, now: now)
    }

    /// The one instance of [T] for the whole app run: repositories that hold state or listeners.
    func shared<T: AnyObject>(_ make: () -> T) -> T {
        if let existing = singletons[ObjectIdentifier(T.self)] as? T { return existing }
        let new = make()
        singletons[ObjectIdentifier(T.self)] = new
        return new
    }

    static func live() -> AppContainer {
        AppContainer(modelContainer: Database.makeContainer())
    }

    /// Previews, unit and UI tests: an empty in-memory database and empty settings.
    static func inMemory(now: @escaping () -> Date = { Date() }) -> AppContainer {
        let suite = "inMemory-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return AppContainer(modelContainer: Database.makeContainer(inMemory: true), defaults: defaults, now: now)
    }
}

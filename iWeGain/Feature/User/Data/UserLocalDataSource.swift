import Foundation

/// The selected person, kept in UserDefaults (Android keeps it in DataStore under the same key).
final class UserLocalDataSource: BaseDataSource {
    private let defaults: UserDefaults
    private let store: LocalStore

    init(defaults: UserDefaults, store: LocalStore) {
        self.defaults = defaults
        self.store = store
    }

    func observeSavedSelection() -> AsyncStream<String?> {
        observe(store) { [self] in savedSelection() }
    }

    func savedSelection() -> String? { defaults.string(forKey: Self.selectedUserKey) }

    func saveSelection(_ userId: String) {
        defaults.set(userId, forKey: Self.selectedUserKey)
        store.notifyChanged()
    }

    private static let selectedUserKey = "selected_user_id"
}

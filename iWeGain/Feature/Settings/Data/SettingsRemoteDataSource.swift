@preconcurrency import FirebaseFirestore
import Foundation

/// The user's settings in `users/{uid}/settings/app`. Read once on sign-in and written on each change; nothing
/// listens to it, so changes made on other devices only arrive with the next sign-in.
final class SettingsRemoteDataSource: BaseDataSource {
    private let provider: FirestoreProvider

    init(provider: FirestoreProvider) {
        self.provider = provider
    }

    /// The saved fields, straight from the server; nil when the account has none yet.
    func fetch(uid: String) async throws(DataError) -> SettingsFields? {
        guard let doc = document(uid) else { throw .network(.unknown) }
        return try await firestoreRequest { (try await doc.getDocument(source: .server).data()).map(SettingsFields.init) }
    }

    /// Merges [fields] into the saved settings. Not awaited: offline, Firestore keeps the write and sends it later.
    func save(uid: String, fields: [String: Any]) {
        document(uid)?.setData(fields, merge: true)
    }

    private func document(_ uid: String) -> DocumentReference? {
        provider.userCollection(uid, "settings")?.document("app")
    }
}

/// The account's saved settings. Fields it doesn't have are nil and leave this device's as they are.
nonisolated struct SettingsFields: Equatable, Sendable {
    var weightUnit: WeightUnit?
    var defaultRestSeconds: Int?
    var workoutReminders: Bool?
    var reminderMinutesBefore: Int?
    var themeMode: ThemeMode?

    init(weightUnit: WeightUnit? = nil, defaultRestSeconds: Int? = nil, workoutReminders: Bool? = nil, reminderMinutesBefore: Int? = nil, themeMode: ThemeMode? = nil) {
        self.weightUnit = weightUnit
        self.defaultRestSeconds = defaultRestSeconds
        self.workoutReminders = workoutReminders
        self.reminderMinutesBefore = reminderMinutesBefore
        self.themeMode = themeMode
    }

    init(_ data: [String: Any]) {
        weightUnit = data.string("weightUnit").flatMap(WeightUnit.init(rawValue:))
        defaultRestSeconds = data.int("defaultRestSeconds")
        workoutReminders = data.bool("workoutReminders")
        reminderMinutesBefore = data.int("reminderMinutesBefore")
        // Older app versions wrote only a dark mode switch.
        themeMode = data.string("themeMode").flatMap(ThemeMode.init(rawValue:)) ?? data.bool("darkMode").map { $0 ? .dark : .light }
    }
}

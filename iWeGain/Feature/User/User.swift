import Foundation

/// A person whose progress is tracked on this device.
nonisolated struct User: Identifiable, Hashable, Sendable {
    /// Id of the local guest profile; its data moves to the account on sign-in.
    static let guestId = "guest"

    let id: String
    var name: String
    /// nil for the local guest profile, which uses a neutral avatar.
    var avatarColor: AvatarColor?
    /// The local profile used while nobody is signed in. Its name is localized in the UI.
    var isGuest = false
    /// A team member who hasn't allowed access to their data: listed, but can't be selected.
    var isLocked = false
    /// A profile created inside my account, for someone without the app.
    var isProfile = false
    /// JPEG shown instead of the initials when set.
    var photo: Data?

    static let guest = User(id: guestId, name: "", avatarColor: nil, isGuest: true)
}

/// Raw values are what Android and Firestore store.
nonisolated enum AvatarColor: String, CaseIterable, Codable, Sendable {
    case blue = "Blue", pink = "Pink", orange = "Orange", purple = "Purple"
}

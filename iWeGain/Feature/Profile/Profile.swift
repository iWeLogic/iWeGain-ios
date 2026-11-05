import Foundation

/// A person created inside my account, for someone who doesn't use the app: I log their workouts. It has no
/// sign-in of its own and can't become an account; its data lives under its [id] like anyone's, and only I
/// (its owner) can read and change it.
nonisolated struct Profile: Identifiable, Equatable, Sendable {
    let id: String
    var firstName: String
    var lastName: String
    /// Picked at random when the profile is created; shown while it has no [photo].
    var avatarColor: AvatarColor
    /// A small square JPEG.
    var photo: Data?
    /// nil until the server has recorded it.
    var createdAt: Date?

    var name: String { fullName(firstName, lastName) }
}

/// The name and photo a signed-in person chose for themselves (Settings → My profile).
nonisolated struct AccountProfile: Equatable, Sendable {
    var firstName: String
    var lastName: String
    var photo: Data?

    var name: String { fullName(firstName, lastName) }
}

nonisolated func fullName(_ firstName: String, _ lastName: String) -> String {
    [firstName, lastName].map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }.joined(separator: " ")
}

nonisolated enum ProfileError: Error, Equatable {
    case notSignedIn
    /// The photo couldn't be read.
    case photo
    case noInternet
    case unknown
}

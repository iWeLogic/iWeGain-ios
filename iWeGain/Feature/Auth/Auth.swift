import Foundation

/// The signed-in account.
nonisolated struct AuthUser: Equatable, Sendable {
    let id: String
    let name: String?
    let email: String?
    let phoneNumber: String?
    /// Account creation time.
    let createdAt: Date?
    /// The sign-in provider's picture (the Google account photo), if any.
    var photoUrl: URL?
}

nonisolated enum AuthError: Error, Equatable {
    /// The user closed the account picker.
    case cancelled
    case noGoogleAccount
    case tooManyRequests
    case noInternet
    /// Firebase / Google sign-in isn't set up in this build.
    case notConfigured
    /// The Firebase project doesn't allow this sign-in method (provider off).
    case methodDisabled
    /// Confirming the account with a different Google account than the signed-in one.
    case wrongAccount
    case unknown
}

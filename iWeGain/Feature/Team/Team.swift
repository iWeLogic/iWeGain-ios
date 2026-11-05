import Foundation

/// Someone in my team (I'm its owner). Their data is only reachable while they [hasAccess].
nonisolated struct TeamMember: Identifiable, Equatable, Sendable {
    let uid: String
    let name: String
    /// The member allows me to see and change their trainings, exercises, workouts and schedule.
    let hasAccess: Bool
    /// nil until the server has recorded it.
    let joinedAt: Date?

    var id: String { uid }
}

/// A team I'm in, owned by someone else.
nonisolated struct TeamMembership: Identifiable, Equatable, Sendable {
    let ownerUid: String
    let ownerName: String
    let hasAccess: Bool
    let joinedAt: Date?

    var id: String { ownerUid }
}

/// An invite to someone's team: valid for 7 days and for one person.
nonisolated struct TeamInvite: Equatable, Sendable {
    let code: String
    let ownerUid: String
    let ownerName: String
    let expiresAt: Date
    let isUsed: Bool

    /// The link people open: the app's universal link, or the website without the app.
    var link: URL { URL(string: Self.linkPrefix + code)! }

    private static let linkPrefix = "https://iwegain.com/i/"

    /// "AK7-29QX" from https://iwegain.com/i/AK7-29QX; nil for any other link.
    static func code(fromLink url: URL) -> String? {
        let link = url.absoluteString
        guard link.hasPrefix(linkPrefix) else { return nil }
        let code = link.dropFirst(linkPrefix.count).prefix { !"/?#".contains($0) }
        return code.isEmpty ? nil : String(code)
    }
}

nonisolated enum TeamError: Error, Equatable {
    case notSignedIn
    case inviteNotFound
    case inviteExpired
    case inviteUsed
    /// The invite was created by the person trying to join.
    case ownInvite
    case noInternet
    case unknown
}

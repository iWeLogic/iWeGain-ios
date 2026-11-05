import Foundation

/// Teams of the signed-in account: the members of my own team, and the teams I'm in. Each person keeps their
/// data in their own account; a member decides whether their team owner can see and change it. Teams need an
/// account, so everything here is empty while signed out.
final class TeamRepository {
    private static let inviteValidity: TimeInterval = 7 * 24 * 60 * 60

    private let authRepository: AuthRepository
    private let remote: TeamRemoteDataSource
    private let now: () -> Date

    init(authRepository: AuthRepository, remote: TeamRemoteDataSource, now: @escaping () -> Date) {
        self.authRepository = authRepository
        self.remote = remote
        self.now = now
    }

    func observeMyTeam() -> AsyncStream<[TeamMember]> {
        authRepository.observeUser().map { $0?.id }.removeDuplicates().flatMapLatest { [remote] id in
            id.map(remote.observeMembers(ownerUid:)) ?? .single([])
        }
    }

    func observeMemberships() -> AsyncStream<[TeamMembership]> {
        authRepository.observeUser().map { $0?.id }.removeDuplicates().flatMapLatest { [remote] id in
            id.map(remote.observeMemberships(memberUid:)) ?? .single([])
        }
    }

    func createInvite() async throws(TeamError) -> TeamInvite {
        let me = try currentUser()
        do {
            return try await remote.createInvite(ownerUid: me.id, ownerName: Self.displayName(me), expiresAt: now().addingTimeInterval(Self.inviteValidity))
        } catch {
            throw Self.teamError(error)
        }
    }

    /// Looks up an invite and checks it can still be used by me.
    func getInvite(code: String) async throws(TeamError) -> TeamInvite {
        let found: TeamInvite?
        do {
            found = try await remote.getInvite(code: code.uppercased())
        } catch {
            throw Self.teamError(error)
        }
        guard let invite = found else { throw .inviteNotFound }
        if invite.ownerUid == authRepository.currentUser?.id { throw .ownInvite }
        if invite.isUsed { throw .inviteUsed }
        if invite.expiresAt < now() { throw .inviteExpired }
        return invite
    }

    /// Joins the team of [invite] and allows its owner to see and change my data.
    func join(_ invite: TeamInvite) async throws(TeamError) {
        let me = try currentUser()
        if invite.ownerUid == me.id { throw .ownInvite }
        do {
            try await remote.join(invite: invite, memberUid: me.id, memberName: Self.displayName(me))
        } catch {
            throw Self.teamError(error)
        }
    }

    /// As a member: allow or stop [ownerUid] seeing and changing my data.
    func setAccess(ownerUid: String, access: Bool) async throws(TeamError) {
        let me = try currentUser()
        do {
            try await remote.setAccess(ownerUid: ownerUid, memberUid: me.id, access: access)
        } catch {
            throw Self.teamError(error)
        }
    }

    func leaveTeam(ownerUid: String) async throws(TeamError) {
        let me = try currentUser()
        do {
            try await remote.deleteMembership(ownerUid: ownerUid, memberUid: me.id)
        } catch {
            throw Self.teamError(error)
        }
    }

    /// As the owner: removes [memberUid] from my team. Their data stays in their own account.
    func removeMember(_ memberUid: String) async throws(TeamError) {
        let me = try currentUser()
        do {
            try await remote.deleteMembership(ownerUid: me.id, memberUid: memberUid)
        } catch {
            throw Self.teamError(error)
        }
    }

    /// Updates the copies of my name that my team and the teams I'm in show.
    func renameMe(_ name: String) async throws(TeamError) {
        let me = try currentUser()
        do {
            try await remote.rename(uid: me.id, name: name)
        } catch {
            throw Self.teamError(error)
        }
    }

    private func currentUser() throws(TeamError) -> AuthUser {
        guard let user = authRepository.currentUser else { throw .notSignedIn }
        return user
    }

    private static func displayName(_ user: AuthUser) -> String {
        user.name ?? user.phoneNumber ?? user.email ?? ""
    }

    private static func teamError(_ error: DataError) -> TeamError {
        switch error {
        case .network(.noInternet): .noInternet
        case .network(.notFound): .inviteNotFound
        case .network(.unauthorized), .network(.forbidden), .network(.serverError), .network(.cancelled), .network(.unknown), .local: .unknown
        }
    }
}

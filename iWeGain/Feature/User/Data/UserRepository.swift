import Foundation

/// People whose data this device shows, and the globally selected one (shared by Home, Statistics and
/// Calendar). "Me" is the signed-in account, or the local guest while signed out; data is stored per person
/// under their id. Profiles I created inside my account come after my team, oldest first.
final class UserRepository {
    private static let memberColors: [AvatarColor] = [.pink, .orange, .purple]

    private let local: UserLocalDataSource
    private let authRepository: AuthRepository
    private let teamRepository: TeamRepository
    private let profileRepository: ProfileRepository
    private let usersState = StateStream<[User]>([.guest])
    private var task: Task<Void, Never>?

    init(local: UserLocalDataSource, authRepository: AuthRepository, teamRepository: TeamRepository, profileRepository: ProfileRepository) {
        self.local = local
        self.authRepository = authRepository
        self.teamRepository = teamRepository
        self.profileRepository = profileRepository
        // Signed in at launch: "me" is known right away, before the team and profiles load.
        if let account = authRepository.currentUser { usersState.send([Self.user(account, profile: nil)]) }
        task = Task { [weak self, combined = makeUsersStream()] in
            for await users in combined { self?.usersState.send(users) }
        }
    }

    deinit { task?.cancel() }

    /// Me first, then the members of my team (members who haven't allowed access are [User.isLocked]), then the
    /// profiles I created. A member's own name and photo are used once they allow access.
    func observeUsers() -> AsyncStream<[User]> { usersState.stream() }

    /// Me: the signed-in account, or the guest.
    func observeMe() -> AsyncStream<User> {
        observeUsers().map { $0[0] }.removeDuplicates()
    }

    func observeMeId() -> AsyncStream<String> {
        observeUsers().map { $0[0].id }.removeDuplicates()
    }

    /// Ids of everyone whose data this device keeps: me, team members who allow access, and my profiles.
    func observeReachableUserIds() -> AsyncStream<Set<String>> {
        observeUsers().map { Set($0.filter { !$0.isLocked }.map(\.id)) }.removeDuplicates()
    }

    var reachableUserIds: Set<String> { Set(usersState.value.filter { !$0.isLocked }.map(\.id)) }

    /// The saved selection while that person is still reachable and unlocked, otherwise me.
    func observeSelectedUserId() -> AsyncStream<String> {
        combineLatest(observeUsers(), local.observeSavedSelection())
            .map { users, saved in Self.selected(users, saved: saved) }
            .removeDuplicates()
    }

    /// The selected person right now (the same rule as [observeSelectedUserId]), for actions such as saving a new training.
    var selectedUserId: String { Self.selected(usersState.value, saved: local.savedSelection()) }

    func selectUser(_ userId: String) {
        local.saveSelection(userId)
    }

    private static func selected(_ users: [User], saved: String?) -> String {
        users.first { $0.id == saved && !$0.isLocked }?.id ?? users[0].id
    }

    private func makeUsersStream() -> AsyncStream<[User]> {
        let me = combineLatest(authRepository.observeUser(), profileRepository.observeMyProfile())
            .map { account, profile in account.map { Self.user($0, profile: profile) } ?? User.guest }
        let profiles = profileRepository.observeProfiles().map { profiles in
            profiles
                .sorted { ($0.createdAt ?? .distantFuture) < ($1.createdAt ?? .distantFuture) }
                .map { User(id: $0.id, name: $0.name, avatarColor: $0.avatarColor, isProfile: true, photo: $0.photo) }
        }
        return combineLatest(me, observeMembers(), profiles).map { me, members, profiles in [me] + members + profiles }
    }

    private func observeMembers() -> AsyncStream<[User]> {
        teamRepository.observeMyTeam().flatMapLatest { [profileRepository] team in
            let members = team.sorted { ($0.joinedAt ?? .distantFuture) < ($1.joinedAt ?? .distantFuture) }
            let own = members.map { member in
                member.hasAccess ? profileRepository.observeAccountProfile(uid: member.uid) : AsyncStream<AccountProfile?>.single(nil)
            }
            return combineLatest(own).map { profiles in
                members.enumerated().map { index, member in
                    User(
                        id: member.uid,
                        name: profiles[index]?.name.nonBlank ?? member.name,
                        avatarColor: Self.memberColors[index % Self.memberColors.count],
                        isLocked: !member.hasAccess,
                        photo: profiles[index]?.photo
                    )
                }
            }
        }
    }

    /// The name I set in My profile; otherwise the account's: Google accounts have one, phone accounts often only a number.
    private static func user(_ account: AuthUser, profile: AccountProfile?) -> User {
        User(
            id: account.id,
            name: profile?.name.nonBlank ?? account.name ?? account.phoneNumber ?? account.email ?? "",
            avatarColor: .blue,
            photo: profile?.photo
        )
    }
}

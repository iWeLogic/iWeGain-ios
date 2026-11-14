import Foundation

/// Profiles I created inside my account for people without the app, and my own name and photo. Both need an
/// account: signed out there are no profiles, and creating one fails.
final class ProfileRepository {
    private static let googlePhotoSize = 512

    private let authRepository: AuthRepository
    private let remote: ProfileRemoteDataSource
    private let accountRemote: AccountRemoteDataSource
    private let teamRepository: TeamRepository
    private var startTask: Task<Void, Never>?

    init(authRepository: AuthRepository, remote: ProfileRemoteDataSource, accountRemote: AccountRemoteDataSource, teamRepository: TeamRepository) {
        self.authRepository = authRepository
        self.remote = remote
        self.accountRemote = accountRemote
        self.teamRepository = teamRepository
    }

    /// On sign-in, an account that has never set its own name and photo starts with the Google account's (or the
    /// name Apple gives): the name split into name and surname, and its photo. It happens once; after that My
    /// profile decides, even when the photo is removed. Offline it's tried again on the next start. Tried again
    /// when the name arrives: Apple's comes just after the sign-in.
    func start() {
        guard startTask == nil else { return }
        startTask = Task { [self] in
            var last: (id: String?, name: String?) = (nil, nil)
            for await user in authRepository.observeUser() where user?.id != last.id || user?.name != last.name {
                last = (user?.id, user?.name)
                if let user { await importAccountProfile(user) }
            }
        }
    }

    private func importAccountProfile(_ user: AuthUser) async {
        let existing: AccountProfile?
        do {
            existing = try await remote.fetchAccountProfile(uid: user.id)
        } catch {
            return
        }
        guard existing == nil else { return }
        let name = user.name?.trimmingCharacters(in: .whitespaces) ?? ""
        let photo = await user.photoUrl.flatMap { Self.largeGooglePhoto($0) }.asyncFlatMap { await ProfilePhotoProcessor.jpeg(from: $0) }
        if name.isEmpty && photo == nil { return }
        let parts = name.split(separator: " ", maxSplits: 1).map(String.init)
        try? remote.saveAccountProfile(uid: user.id, profile: AccountProfile(
            firstName: parts.first ?? "",
            lastName: parts.count > 1 ? parts[1].trimmingCharacters(in: .whitespaces) : "",
            photo: photo
        ))
    }

    /// Google serves its account photo at 96 px by default (`=s96-c`); asks for one big enough for the 256 px avatar.
    private static func largeGooglePhoto(_ url: URL) -> URL {
        let text = url.absoluteString.replacing(/=s\d+-c$/, with: "=s\(googlePhotoSize)-c")
        return URL(string: text) ?? url
    }

    func observeProfiles() -> AsyncStream<[Profile]> {
        authRepository.observeUser().map { $0?.id }.removeDuplicates().flatMapLatest { [remote] id in
            id.map(remote.observeProfiles(ownerUid:)) ?? .single([])
        }
    }

    func profile(id: String) async -> Profile? {
        await observeProfiles().first()?.first { $0.id == id }
    }

    /// My own name and photo; nil while signed out or until I set them.
    func observeMyProfile() -> AsyncStream<AccountProfile?> {
        authRepository.observeUser().map { $0?.id }.removeDuplicates().flatMapLatest { [remote] id in
            id.map(remote.observeAccountProfile(uid:)) ?? .single(nil)
        }
    }

    /// Someone else's own name and photo (a member of my team who allows access); nil when not readable.
    func observeAccountProfile(uid: String) -> AsyncStream<AccountProfile?> {
        remote.observeAccountProfile(uid: uid)
    }

    /// A new profile gets a random color, shown while it has no photo.
    func createProfile(firstName: String, lastName: String, photo: Data?) throws(ProfileError) -> Profile {
        guard let me = authRepository.currentUser else { throw .notSignedIn }
        let profile = Profile(
            id: UUID().uuidString,
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            avatarColor: AvatarColor.allCases.randomElement() ?? .pink,
            photo: photo,
            createdAt: nil
        )
        do {
            try remote.saveProfile(ownerUid: me.id, profile: profile, isNew: true)
        } catch {
            throw Self.profileError(error)
        }
        return profile
    }

    func updateProfile(_ profile: Profile) throws(ProfileError) {
        guard let me = authRepository.currentUser else { throw .notSignedIn }
        var trimmed = profile
        trimmed.firstName = profile.firstName.trimmingCharacters(in: .whitespaces)
        trimmed.lastName = profile.lastName.trimmingCharacters(in: .whitespaces)
        do {
            try remote.saveProfile(ownerUid: me.id, profile: trimmed, isNew: false)
        } catch {
            throw Self.profileError(error)
        }
    }

    /// Deletes a profile and everything it has (trainings, workouts, schedule) from Firestore; the device drops
    /// its copy once the profile is gone from the list. Needs a connection.
    func deleteProfile(id: String) async throws(ProfileError) {
        guard let me = authRepository.currentUser else { throw .notSignedIn }
        do {
            try await accountRemote.deleteProfileData(profileId: id)
            try await remote.deleteProfile(ownerUid: me.id, profileId: id)
        } catch {
            throw Self.profileError(error)
        }
    }

    /// Saves my own name and photo, and the copies of my name in the teams I'm part of (best effort, online only).
    func updateMyProfile(firstName: String, lastName: String, photo: Data?) async throws(ProfileError) {
        guard let me = authRepository.currentUser else { throw .notSignedIn }
        let profile = AccountProfile(
            firstName: firstName.trimmingCharacters(in: .whitespaces),
            lastName: lastName.trimmingCharacters(in: .whitespaces),
            photo: photo
        )
        do {
            try remote.saveAccountProfile(uid: me.id, profile: profile)
        } catch {
            throw Self.profileError(error)
        }
        try? await teamRepository.renameMe(profile.name)
    }

    private static func profileError(_ error: DataError) -> ProfileError {
        error == .network(.noInternet) ? .noInternet : .unknown
    }
}

private extension Optional where Wrapped: Sendable {
    func asyncFlatMap<T>(_ transform: (Wrapped) async -> T?) async -> T? {
        guard let self else { return nil }
        return await transform(self)
    }
}

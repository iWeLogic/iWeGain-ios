/// Account actions that touch more than sign-in itself.
final class AccountRepository {
    private let authRepository: AuthRepository
    private let syncManager: SyncManager
    private let deviceDataSource: DeviceDataSource
    private let pushRepository: PushRepository
    private let settingsRepository: SettingsRepository
    private let remote: AccountRemoteDataSource
    private let network: NetworkMonitor

    init(
        authRepository: AuthRepository,
        syncManager: SyncManager,
        deviceDataSource: DeviceDataSource,
        pushRepository: PushRepository,
        settingsRepository: SettingsRepository,
        remote: AccountRemoteDataSource,
        network: NetworkMonitor
    ) {
        self.authRepository = authRepository
        self.syncManager = syncManager
        self.deviceDataSource = deviceDataSource
        self.pushRepository = pushRepository
        self.settingsRepository = settingsRepository
        self.remote = remote
        self.network = network
    }

    /// Signs out and deletes this device's copy of the user's data. It stays in Firestore and comes back on the
    /// next sign-in; changes that weren't uploaded yet are lost. The app then starts over as an empty guest.
    func logOut() async {
        // While still signed in: the account's pushes must stop coming to this device.
        await pushRepository.unregister()
        authRepository.signOut()
        await clearDevice()
    }

    /// Deletes the account for good: after the user confirms their Google account, all of their data in
    /// Firestore, then the account itself, then this device's copy. The app then starts over as an empty guest.
    /// [AuthError.cancelled] when they closed the account picker.
    func deleteAccount() async throws(AuthError) {
        guard network.isOnline else { throw .noInternet }
        guard let uid = authRepository.currentUser?.id else { throw .unknown }
        // First, so nothing is deleted when the account itself couldn't be.
        try await authRepository.reauthenticateWithGoogle()
        await pushRepository.unregister()
        do {
            try await remote.deleteUserData(uid: uid)
        } catch {
            throw error == .network(.noInternet) ? AuthError.noInternet : AuthError.unknown
        }
        try await authRepository.deleteUser()
        authRepository.signOut()
        await clearDevice()
    }

    private func clearDevice() async {
        // Sync must be fully stopped first, or a late server change could be written back after clearing.
        await syncManager.awaitStopped()
        try? deviceDataSource.clearDatabase()
        try? await deviceDataSource.clearFirestoreCache()
        // Settings stay on the device, but the next sign-in replaces them with that account's.
        settingsRepository.forgetAccount()
    }
}

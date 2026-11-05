@preconcurrency import FirebaseFirestore
import FirebaseInstallations
import FirebaseMessaging
import Foundation

/// Registers this device for "schedule changed" pushes in `users/{uid}/devices/{deviceId}` while someone is
/// signed in. The time zone lets the server work out "within 24 hours".
final class PushRepository: BaseDataSource {
    private let authRepository: AuthRepository
    private let provider: FirestoreProvider
    private var task: Task<Void, Never>?

    init(authRepository: AuthRepository, provider: FirestoreProvider) {
        self.authRepository = authRepository
        self.provider = provider
    }

    /// Registers on every sign-in (and app start while signed in).
    func start() {
        guard task == nil, AppFirebase.isConfigured else { return }
        task = Task { [self] in
            for await uid in authRepository.observeUser().map({ $0?.id }).removeDuplicates() where uid != nil {
                await register(token: nil)
            }
        }
    }

    /// Saves [token], or the current one, for the signed-in user. Also for a new token or time zone.
    func register(token: String?) async {
        guard AppFirebase.isConfigured, let uid = authRepository.currentUser?.id,
              let deviceId = try? await Installations.installations().installationID(),
              let current = await currentToken(token) else { return }
        try? await provider.userCollection(uid, "devices")?.document(deviceId).setData([
            "token": current,
            "platform": "ios",
            "timeZone": TimeZone.current.identifier,
            "updatedAt": FieldValue.serverTimestamp(),
        ], merge: true)
    }

    /// Before signing out: this device should no longer get that account's pushes.
    func unregister() async {
        guard AppFirebase.isConfigured, let uid = authRepository.currentUser?.id else { return }
        if let deviceId = try? await Installations.installations().installationID() {
            try? await provider.userCollection(uid, "devices")?.document(deviceId).delete()
        }
        // Offline: the server drops the stale token the first time a push to it fails.
        try? await Messaging.messaging().deleteToken()
    }

    /// Without an APNs token yet (simulators, or before the system answers) there's no FCM token either.
    private func currentToken(_ token: String?) async -> String? {
        if let token { return token }
        return try? await Messaging.messaging().token()
    }
}

extension AppContainer {
    var pushRepository: PushRepository { shared { PushRepository(authRepository: authRepository, provider: firestore) } }
}

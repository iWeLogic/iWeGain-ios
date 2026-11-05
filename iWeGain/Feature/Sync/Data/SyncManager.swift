import Foundation

/// Two-way sync between the local database and Firestore while someone is signed in.
///
/// The database stays the source of truth for the UI, so the app works the same offline. Local changes mark
/// rows dirty and are uploaded; server changes are written unless this device has a newer copy (last write
/// wins by `updatedAt`). Signed out, nothing syncs; changes made meanwhile stay dirty and are uploaded after
/// the next sign-in. Besides my own data it syncs every team member who allows access and my profiles, each
/// under their own account. When someone stops being reachable, their data is removed from here.
///
/// [status] tells whether everything from the server is on the device: the splash screen waits for the first
/// load, and the header shows "Offline" when it failed. While offline, sync restarts every minute (Firestore
/// also reconnects by itself when the network comes back).
final class SyncManager {
    private static let initialBackoff: Duration = .seconds(2)
    private static let maxBackoff: Duration = .seconds(5 * 60)
    private static let loadTimeout: Duration = .seconds(10)
    private static let retryInterval: Duration = .seconds(60)

    private let authRepository: AuthRepository
    private let userRepository: UserRepository
    private let collections: [SyncedCollection]
    private let deviceDataSource: DeviceDataSource
    private let network: NetworkMonitor

    private let statusState = StateStream(SyncStatus.loading)
    private let retries = StateStream(0)
    private let isSyncing = StateStream(false)
    private var tasks: [Task<Void, Never>] = []
    private var syncTask: Task<Void, Never>?
    private var isStarted = false
    private var synced = Set<String>()

    init(
        authRepository: AuthRepository,
        userRepository: UserRepository,
        collections: [SyncedCollection],
        deviceDataSource: DeviceDataSource,
        network: NetworkMonitor
    ) {
        self.authRepository = authRepository
        self.userRepository = userRepository
        self.collections = collections
        self.deviceDataSource = deviceDataSource
        self.network = network
    }

    var status: SyncStatus { statusState.value }

    func observeStatus() -> AsyncStream<SyncStatus> { statusState.stream() }

    /// Waits until sync has fully stopped, e.g. after signing out.
    func awaitStopped() async {
        syncTask?.cancel()
        for await syncing in isSyncing.stream() where !syncing { return }
    }

    func start() {
        guard !isStarted else { return }
        isStarted = true
        // Never keep the splash screen waiting for long, e.g. when the team can't be loaded offline.
        tasks.append(Task { [self] in
            try? await Task.sleep(for: Self.loadTimeout)
            if status == .loading { statusState.send(.offline) }
        })
        tasks.append(Task { [self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: Self.retryInterval)
                if status == .offline { retries.send(retries.value + 1) }
            }
        })
        tasks.append(Task { [self] in
            let meIds = authRepository.observeUser().map { $0?.id }.removeDuplicates()
            // Signing out, switching accounts, a change in the team or a retry restarts sync.
            for await (me, reachable, _) in combineLatest(meIds, userRepository.observeReachableUserIds(), retries.stream()) {
                syncTask?.cancel()
                let previous = syncTask
                syncTask = Task { [self] in
                    await previous?.value
                    guard !Task.isCancelled else { return }
                    await restart(me: me, reachable: reachable)
                }
            }
        })
    }

    private func restart(me: String?, reachable: Set<String>) async {
        guard let me else {
            synced = []
            // Signed out, everything stays on the device: nothing to load.
            statusState.send(.upToDate)
            return
        }
        let people = reachable.union([me])
        // Members who withdrew access, left or were removed: their data no longer belongs here.
        for uid in synced.subtracting(people).subtracting([me]) { try? deviceDataSource.deletePersonData(uid: uid) }
        synced = people
        await sync(me: me, people: people)
    }

    private func sync(me: String, people: Set<String>) async {
        isSyncing.send(true)
        defer { isSyncing.send(false) }
        // Anything made as the guest belongs to the account now, so it's uploaded with the rest.
        try? deviceDataSource.claimGuestData(uid: me)
        // Without a connection there's nothing to wait for; the splash screen can go right away.
        if !network.isOnline && status == .loading { statusState.send(.offline) }

        let listeners = ListenerStates(expected: people.count * collections.count)
        var running: [Task<Void, Never>] = [Task { [self] in
            // Up to date once every listener has caught up; offline when they haven't within the timeout.
            try? await Task.sleep(for: Self.loadTimeout)
            if !Task.isCancelled && !listeners.isAllFromServer { statusState.send(.offline) }
        }]
        for uid in people {
            for collection in collections {
                let key = "\(uid)/\(collection.name)"
                running.append(Task { [self] in
                    await Self.keepRunning {
                        try await collection.pullChanges(uid: uid) { [self] isFromServer in
                            listeners.update(key, isFromServer: isFromServer)
                            if listeners.isAllFromServer {
                                statusState.send(.upToDate)
                            } else if listeners.isConnectionLost {
                                statusState.send(.offline)
                            }
                        }
                    }
                })
                running.append(Task {
                    await Self.keepRunning { try await collection.pushChanges(uid: uid) }
                })
            }
        }
        let tasks = running
        await withTaskCancellationHandler {
            for task in tasks { await task.value }
        } onCancel: {
            tasks.forEach { $0.cancel() }
        }
    }

    /// One upload and download pass for me and everyone reachable, without listeners: for background sync
    /// while the app isn't running. False when something couldn't be synced.
    func syncOnce() async -> Bool {
        guard let me = authRepository.currentUser?.id else { return true }
        try? deviceDataSource.claimGuestData(uid: me)
        var isSynced = true
        for uid in userRepository.reachableUserIds.union([me]) {
            for collection in collections {
                // Exercises come first, so trainings that use custom exercises can resolve them.
                do {
                    if try await !collection.pushOnce(uid: uid) { isSynced = false }
                    try await collection.pullOnce(uid: uid)
                } catch {
                    isSynced = false
                }
            }
        }
        return isSynced
    }

    /// Restarts [run] after it stops with an error (offline, permission denied, ...), backing off.
    private static func keepRunning(_ run: @escaping @MainActor () async throws -> Void) async {
        var backoff = initialBackoff
        while !Task.isCancelled {
            do {
                try await run()
                backoff = initialBackoff
            } catch is CancellationError {
                return
            } catch {
                // The next wait gets longer below.
            }
            guard !Task.isCancelled else { return }
            try? await Task.sleep(for: backoff)
            backoff = min(backoff * 2, maxBackoff)
        }
    }
}

/// How far each Firestore listener has got during one sync.
@MainActor
private final class ListenerStates {
    private enum State { case waiting, server, lost }

    private let expected: Int
    private var states: [String: State] = [:]

    init(expected: Int) {
        self.expected = expected
    }

    var isAllFromServer: Bool { states.count == expected && states.values.allSatisfy { $0 == .server } }
    var isConnectionLost: Bool { states.values.contains(.lost) }

    func update(_ key: String, isFromServer: Bool) {
        if isFromServer {
            states[key] = .server
        } else if states[key] == .server {
            // Had the server, now only the cache: the connection was lost.
            states[key] = .lost
        } else if states[key] == nil {
            // The cache usually comes first, before the server answers.
            states[key] = .waiting
        }
    }
}

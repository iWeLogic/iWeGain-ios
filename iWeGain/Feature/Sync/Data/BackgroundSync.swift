import Foundation
#if os(iOS)
import BackgroundTasks
#endif

/// Syncs while the app isn't running, then the reminders follow the new data: about every 6 hours when iOS
/// allows it (the counterpart of Android's SyncWorker), and right after a "schedule changed" push.
final class BackgroundSync {
    static let taskId = "com.iwelogic.gain.sync"
    private static let interval: TimeInterval = 6 * 60 * 60

    private let syncManager: SyncManager

    init(syncManager: SyncManager) {
        self.syncManager = syncManager
    }

    /// Must run before the app finishes launching.
    func register() {
        #if os(iOS)
        BGTaskScheduler.shared.register(forTaskWithIdentifier: Self.taskId, using: .main) { [weak self] task in
            nonisolated(unsafe) let task = task
            MainActor.assumeIsolated {
                guard let self else {
                    task.setTaskCompleted(success: false)
                    return
                }
                self.schedule()
                let work = Task { await self.syncManager.syncOnce() }
                task.expirationHandler = { work.cancel() }
                Task {
                    let synced = await work.value
                    task.setTaskCompleted(success: synced)
                }
            }
        }
        #endif
    }

    /// Keeps the next run queued; iOS decides when it really happens.
    func schedule() {
        #if os(iOS)
        let request = BGAppRefreshTaskRequest(identifier: Self.taskId)
        request.earliestBeginDate = Date(timeIntervalSinceNow: Self.interval)
        try? BGTaskScheduler.shared.submit(request)
        #endif
    }
}

extension AppContainer {
    var backgroundSync: BackgroundSync { shared { BackgroundSync(syncManager: syncManager) } }
}

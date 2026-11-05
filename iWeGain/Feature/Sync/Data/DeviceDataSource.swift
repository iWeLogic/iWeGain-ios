@preconcurrency import FirebaseFirestore
import Foundation

/// Everything this device stores for the user: the local database and Firestore's offline cache.
final class DeviceDataSource: BaseDataSource {
    private let tables: [SyncTable]
    private let cursors: SyncCursorDataSource
    private let store: LocalStore
    private let firestore: FirestoreProvider

    init(tables: [SyncTable], cursors: SyncCursorDataSource, store: LocalStore, firestore: FirestoreProvider) {
        self.tables = tables
        self.cursors = cursors
        self.store = store
        self.firestore = firestore
    }

    /// Gives everything created as the guest to the account [uid] and queues it for upload.
    func claimGuestData(uid: String) throws(DataError) {
        try dbRequest {
            try tables.forEach { try $0.reassign(from: User.guestId, to: uid) }
            try store.save()
        }
    }

    /// Removes a team member's data from this device once it's no longer reachable (access withdrawn, left
    /// or removed). It stays in their own account.
    func deletePersonData(uid: String) throws(DataError) {
        try dbRequest {
            try tables.forEach { try $0.deleteRows(uid: uid) }
            try cursors.deleteCursors(uid: uid)
            try store.save()
        }
    }

    /// Deletes every row of every synced table and the sync bookkeeping.
    func clearDatabase() throws(DataError) {
        try dbRequest {
            try tables.forEach { try $0.deleteAll() }
            try cursors.deleteAll()
            try store.save()
        }
    }

    /// Removes cached documents and unsent writes; the instance has to be shut down first.
    func clearFirestoreCache() async throws(DataError) {
        guard let firestore = firestore.firestore else { return }
        try await firestoreRequest {
            try await firestore.terminate()
            try await firestore.clearPersistence()
        }
    }
}

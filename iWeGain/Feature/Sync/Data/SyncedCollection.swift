@preconcurrency import FirebaseFirestore
import Foundation
import SwiftData

/// Connects a [SyncTable] with its Firestore collection: applies server changes and uploads local ones.
final class SyncedCollection: BaseDataSource {
    /// Set by Firestore's server on every upload; incremental sync listens from the newest one already saved.
    static let serverUpdatedAt = "serverUpdatedAt"

    let table: SyncTable
    private let firestore: FirestoreProvider
    private let cursors: SyncCursorDataSource
    private let store: LocalStore
    /// Uploads Firestore has been given and hasn't confirmed, by row id. Offline they wait in Firestore's own
    /// queue, so they aren't sent again each time sync restarts.
    private var uploading: [String: Int64] = [:]

    var name: String { table.name }

    init(table: SyncTable, firestore: FirestoreProvider, cursors: SyncCursorDataSource, store: LocalStore) {
        self.table = table
        self.firestore = firestore
        self.cursors = cursors
        self.store = store
    }

    /// Applies server changes until cancelled, or throws when the listener fails. [onServerState] gets true once
    /// everything the server has is here, and false while only Firestore's offline cache is available.
    func pullChanges(uid: String, onServerState: @escaping (Bool) -> Void) async throws {
        guard let collection = firestore.userCollection(uid, name) else { return }
        // First start: the whole collection. Afterwards only what changed since the saved cursor.
        let query = query(collection, uid: uid)
        let listener = PullListener()
        var wasFromServer: Bool?
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                listener.continuation = continuation
                if Task.isCancelled {
                    listener.finish(nil)
                    return
                }
                // Metadata changes too, to hear when the listener catches up with the server or falls back to the cache.
                listener.registration = query.addSnapshotListener(includeMetadataChanges: true) { [self] snapshot, error in
                    if let error {
                        listener.finish(error)
                        return
                    }
                    guard let snapshot else { return }
                    let isFromServer = !snapshot.metadata.isFromCache
                    // This device's own writes are skipped until the server confirms them.
                    let changed = snapshot.documentChanges
                        .filter { $0.type != .removed && !$0.document.metadata.hasPendingWrites }
                        .map(\.document)
                    if !changed.isEmpty || isFromServer != wasFromServer {
                        wasFromServer = isFromServer
                        apply(changed, uid: uid)
                        onServerState(isFromServer)
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in listener.finish(nil) }
        }
    }

    /// Uploads rows changed on this device, whenever there are any, until cancelled.
    func pushChanges(uid: String) async throws {
        for await _ in store.changes() {
            try upload(uid: uid)
        }
    }

    /// Applies what changed on the server since the last sync, once (background sync).
    func pullOnce(uid: String) async throws {
        guard let collection = firestore.userCollection(uid, name) else { return }
        let snapshot = try await query(collection, uid: uid).getDocuments(source: .server)
        apply(snapshot.documents, uid: uid)
    }

    /// Uploads the rows changed on this device and waits a little for them to arrive (background sync).
    /// Returns false when some are still on their way.
    func pushOnce(uid: String) async throws -> Bool {
        try upload(uid: uid)
        for _ in 0..<100 where !uploading.isEmpty {
            try await Task.sleep(for: .milliseconds(100))
        }
        return uploading.isEmpty
    }

    private func query(_ collection: CollectionReference, uid: String) -> Query {
        guard let since = cursors.get(uid: uid, collection: name) else { return collection }
        return collection.whereField(Self.serverUpdatedAt, isGreaterThanOrEqualTo: Timestamp(seconds: since.seconds, nanoseconds: since.nanoseconds))
    }

    /// Writes server documents to the database and moves the cursor past them. The cursor moves only once
    /// everything is saved; anything that failed is fetched again next start.
    private func apply(_ documents: [DocumentSnapshot], uid: String) {
        guard !documents.isEmpty else { return }
        do {
            for document in documents {
                guard let data = document.data() else { continue }
                try table.applyRemote(id: document.documentID, fields: data, uid: uid)
            }
            let newest = documents.compactMap { $0.get(Self.serverUpdatedAt) as? Timestamp }
                .max { ($0.seconds, $0.nanoseconds) < ($1.seconds, $1.nanoseconds) }
            if let newest {
                try cursors.advance(uid: uid, collection: name, newest: .init(seconds: newest.seconds, nanoseconds: newest.nanoseconds))
            }
            try store.save()
        } catch {
            store.context.rollback()
        }
    }

    private func upload(uid: String) throws {
        guard let collection = firestore.userCollection(uid, name) else { return }
        for row in try table.dirtyRows(uid: uid) where uploading[row.id] != row.updatedAt {
            uploading[row.id] = row.updatedAt
            var fields = row.fields
            fields[Self.serverUpdatedAt] = FieldValue.serverTimestamp()
            let id = row.id, updatedAt = row.updatedAt
            collection.document(id).setData(fields) { [weak self] error in
                let succeeded = error == nil
                Task { @MainActor in self?.finishUpload(id: id, updatedAt: updatedAt, succeeded: succeeded) }
            }
        }
    }

    private func finishUpload(id: String, updatedAt: Int64, succeeded: Bool) {
        if uploading[id] == updatedAt { uploading[id] = nil }
        // On failure the row stays dirty and goes again with the next change or sync restart.
        guard succeeded else { return }
        try? table.markClean(id: id, updatedAt: updatedAt)
        try? store.save()
    }
}

/// A running snapshot listener and whoever waits for it to end.
@MainActor
private final class PullListener {
    var registration: ListenerRegistration?
    var continuation: CheckedContinuation<Void, Error>?

    func finish(_ error: Error?) {
        registration?.remove()
        registration = nil
        guard let continuation else { return }
        self.continuation = nil
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }
}

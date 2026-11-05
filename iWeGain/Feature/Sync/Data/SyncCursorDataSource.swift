import Foundation
import SwiftData

/// Where each collection's incremental sync left off (see [SyncCursorEntity]).
final class SyncCursorDataSource: BaseDataSource {
    struct Cursor: Equatable {
        let seconds: Int64
        let nanoseconds: Int32
    }

    private let store: LocalStore

    init(store: LocalStore) {
        self.store = store
    }

    /// nil before the first full load of [collection] for [uid] (or when it can't be read: then everything is loaded again).
    func get(uid: String, collection: String) -> Cursor? {
        (try? entity(uid: uid, collection: collection)).flatMap { $0 }.map { Cursor(seconds: $0.seconds, nanoseconds: $0.nanoseconds) }
    }

    /// Moves the cursor forward; an older [newest] is ignored. No save.
    func advance(uid: String, collection: String, newest: Cursor) throws {
        if let row = try entity(uid: uid, collection: collection) {
            if (newest.seconds, newest.nanoseconds) > (row.seconds, row.nanoseconds) {
                row.seconds = newest.seconds
                row.nanoseconds = newest.nanoseconds
            }
        } else {
            store.context.insert(SyncCursorEntity(uid: uid, collection: collection, seconds: newest.seconds, nanoseconds: newest.nanoseconds))
        }
    }

    func deleteCursors(uid: String) throws {
        try store.context.fetch(FetchDescriptor<SyncCursorEntity>(predicate: #Predicate { $0.uid == uid })).forEach { store.context.delete($0) }
    }

    func deleteAll() throws {
        try store.context.fetch(FetchDescriptor<SyncCursorEntity>()).forEach { store.context.delete($0) }
    }

    private func entity(uid: String, collection: String) throws -> SyncCursorEntity? {
        let key = "\(uid)/\(collection)"
        return try store.context.fetch(FetchDescriptor<SyncCursorEntity>(predicate: #Predicate { $0.key == key })).first
    }
}

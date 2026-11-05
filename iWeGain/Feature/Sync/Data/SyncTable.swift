import Foundation

/// A local row ready to upload: its id, version and Firestore fields.
nonisolated struct SyncUpload: @unchecked Sendable {
    let id: String
    let updatedAt: Int64
    let fields: [String: Any]
}

/// One SwiftData table kept in sync with the Firestore collection `users/{uid}/{name}`. A new synced table
/// needs `updatedAt` and `isDirty` columns, a `<Name>SyncDataSource` implementing this, and an entry in
/// [SyncManager]. Conforming types only touch the local database; [SyncedCollection] talks to Firestore.
@MainActor
protocol SyncTable: AnyObject {
    /// The Firestore collection's name, which also identifies this table in sync bookkeeping.
    var name: String { get }

    /// [uid]'s rows changed on this device and not uploaded yet.
    func dirtyRows(uid: String) throws -> [SyncUpload]

    /// Writes a server document unless this device has a newer copy (last write wins). No save: the caller
    /// saves the batch. A document it can't read is skipped. [uid] is the person whose collection it came from.
    func applyRemote(id: String, fields: [String: Any], uid: String) throws

    /// Marks a row uploaded, unless it changed again while uploading. No save.
    func markClean(id: String, updatedAt: Int64) throws

    /// Gives every row of [from] (the guest) to [to] (the signed-in account) and queues them for upload. No save.
    func reassign(from: String, to: String) throws

    /// Removes a person's rows from this device. No save.
    func deleteRows(uid: String) throws

    /// Removes every row. No save.
    func deleteAll() throws
}

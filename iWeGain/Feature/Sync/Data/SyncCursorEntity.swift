import Foundation
import SwiftData

/// The newest server change already saved here, per account and Firestore collection. Later starts only
/// listen for changes from this point; without a row the whole collection is loaded. Stored as a Firestore
/// Timestamp's seconds and nanoseconds, so nothing is lost to rounding.
@Model
final class SyncCursorEntity {
    @Attribute(.unique) var key: String
    var uid: String
    var collection: String
    var seconds: Int64
    var nanoseconds: Int32

    init(uid: String, collection: String, seconds: Int64, nanoseconds: Int32) {
        key = "\(uid)/\(collection)"
        self.uid = uid
        self.collection = collection
        self.seconds = seconds
        self.nanoseconds = nanoseconds
    }
}

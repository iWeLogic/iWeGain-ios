@preconcurrency import FirebaseFirestore
import Foundation

/// Everything an account owns in Firestore, for deleting the account. The security rules let the user delete all of it.
final class AccountRemoteDataSource: BaseDataSource {
    /// Every collection under `users/{uid}`: the synced tables, settings, push devices, my profiles and my own name and photo.
    private static let userCollections = ["customExercises", "trainings", "scheduledTrainings", "workouts", "settings", "devices", "profiles", "profile"]
    /// What a profile created inside an account has: only the synced tables.
    private static let profileCollections = ["customExercises", "trainings", "scheduledTrainings", "workouts"]
    /// Firestore allows at most 500 writes in a batch.
    private static let batchSize = 450

    private let provider: FirestoreProvider

    init(provider: FirestoreProvider) {
        self.provider = provider
    }

    /// Deletes the user's own data (`users/{uid}/...`), the data of the profiles they created, their team (its
    /// memberships), the teams they're in and their invites. Reads come from the server, so it fails right away offline.
    func deleteUserData(uid: String) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest {
            var documents: [DocumentReference] = []
            // A profile's data first: the profile document is what lets the owner delete it.
            if let profiles = provider.userCollection(uid, "profiles") {
                for id in try await profiles.getDocuments(source: .server).documents.map(\.documentID) {
                    documents += try await profileDocuments(id)
                }
            }
            for name in Self.userCollections {
                if let collection = provider.userCollection(uid, name) {
                    documents += try await collection.getDocuments(source: .server).documents.map(\.reference)
                }
            }
            documents += try await firestore.collection("teams").document(uid).collection("members").getDocuments(source: .server).documents.map(\.reference)
            documents += try await firestore.collectionGroup("members").whereField("memberUid", isEqualTo: uid).getDocuments(source: .server).documents.map(\.reference)
            documents += try await firestore.collection("invites").whereField("ownerUid", isEqualTo: uid).getDocuments(source: .server).documents.map(\.reference)
            try await delete(firestore, documents)
        }
    }

    /// Deletes everything a profile created inside an account has; the profile document itself stays.
    func deleteProfileData(profileId: String) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest { try await delete(firestore, try await profileDocuments(profileId)) }
    }

    private func profileDocuments(_ profileId: String) async throws -> [DocumentReference] {
        var documents: [DocumentReference] = []
        for name in Self.profileCollections {
            if let collection = provider.userCollection(profileId, name) {
                documents += try await collection.getDocuments(source: .server).documents.map(\.reference)
            }
        }
        return documents
    }

    private func delete(_ firestore: Firestore, _ documents: [DocumentReference]) async throws {
        var start = 0
        while start < documents.count {
            let batch = firestore.batch()
            documents[start..<min(start + Self.batchSize, documents.count)].forEach { batch.deleteDocument($0) }
            try await batch.commit()
            start += Self.batchSize
        }
    }
}

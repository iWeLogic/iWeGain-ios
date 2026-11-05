@preconcurrency import FirebaseFirestore
import Foundation

/// Profiles in Firestore. Profiles I created live at `users/{ownerUid}/profiles/{profileId}`; their data lives
/// under `users/{profileId}/...` like anyone's, which the security rules open to the owner. My own name and
/// photo live at `users/{uid}/profile/info`, readable by team owners I allow.
///
/// Writes aren't awaited: Firestore applies them to its cache (and the listeners) right away and uploads them
/// once online, so editing works offline like the rest of the app.
final class ProfileRemoteDataSource: BaseDataSource {
    private let provider: FirestoreProvider

    init(provider: FirestoreProvider) {
        self.provider = provider
    }

    /// Profiles created by [ownerUid], from Firestore's cache offline; stops quietly on errors.
    func observeProfiles(ownerUid: String) -> AsyncStream<[Profile]> {
        guard let collection = provider.userCollection(ownerUid, "profiles") else { return .single([]) }
        return collection.listen { snapshot in
            snapshot.documents.map { doc in
                let data = doc.data()
                return Profile(
                    id: doc.documentID,
                    firstName: data.string("firstName") ?? "",
                    lastName: data.string("lastName") ?? "",
                    avatarColor: data.string("avatarColor").flatMap(AvatarColor.init(rawValue:)) ?? .pink,
                    photo: data["photo"] as? Data,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue()
                )
            }
        }
    }

    func saveProfile(ownerUid: String, profile: Profile, isNew: Bool) throws(DataError) {
        guard let doc = provider.userCollection(ownerUid, "profiles")?.document(profile.id) else { throw .network(.unknown) }
        var fields: [String: Any] = [
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "avatarColor": profile.avatarColor.rawValue,
            "photo": orNull(profile.photo),
            "updatedAt": FieldValue.serverTimestamp(),
        ]
        if isNew {
            fields["createdAt"] = FieldValue.serverTimestamp()
            doc.setData(fields)
        } else {
            doc.updateData(fields)
        }
    }

    /// Deletes the profile itself; its data has to go first, while it still grants access.
    func deleteProfile(ownerUid: String, profileId: String) async throws(DataError) {
        guard let doc = provider.userCollection(ownerUid, "profiles")?.document(profileId) else { throw .network(.unknown) }
        try await firestoreRequest { try await doc.delete() }
    }

    /// [uid]'s own name and photo; nil until they set them. Errors (no access) count as not set.
    func observeAccountProfile(uid: String) -> AsyncStream<AccountProfile?> {
        guard let doc = accountProfileDoc(uid) else { return .single(nil) }
        return doc.listen(fallback: nil) { data in data.map(Self.accountProfile) }
    }

    /// [uid]'s own name and photo as the server has them; nil when they were never set. Fails offline.
    func fetchAccountProfile(uid: String) async throws(DataError) -> AccountProfile? {
        guard let doc = accountProfileDoc(uid) else { throw .network(.unknown) }
        return try await firestoreRequest { try await doc.getDocument(source: .server).data().map(Self.accountProfile) }
    }

    func saveAccountProfile(uid: String, profile: AccountProfile) throws(DataError) {
        guard let doc = accountProfileDoc(uid) else { throw .network(.unknown) }
        doc.setData([
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "photo": orNull(profile.photo),
            "updatedAt": FieldValue.serverTimestamp(),
        ])
    }

    private func accountProfileDoc(_ uid: String) -> DocumentReference? {
        provider.userCollection(uid, "profile")?.document("info")
    }

    private static func accountProfile(_ data: [String: Any]) -> AccountProfile {
        AccountProfile(firstName: data.string("firstName") ?? "", lastName: data.string("lastName") ?? "", photo: data["photo"] as? Data)
    }
}

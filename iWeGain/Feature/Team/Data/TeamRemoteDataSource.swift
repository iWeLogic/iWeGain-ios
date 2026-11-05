@preconcurrency import FirebaseFirestore
import Foundation

/// Teams in Firestore. A membership lives at `teams/{ownerUid}/members/{memberUid}` and carries both names and
/// the member-controlled `access` flag; a member finds their teams with a collection group query on `memberUid`.
/// Invites live at `invites/{code}`. The security rules enforce who can do what.
final class TeamRemoteDataSource: BaseDataSource {
    private static let codeAlphabet = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")

    private let provider: FirestoreProvider

    init(provider: FirestoreProvider) {
        self.provider = provider
    }

    /// Members of [ownerUid]'s team. Served from Firestore's cache offline; stops quietly on errors.
    func observeMembers(ownerUid: String) -> AsyncStream<[TeamMember]> {
        guard let query = provider.firestore?.collection("teams").document(ownerUid).collection("members") else { return .single([]) }
        return query.listen { snapshot in
            snapshot.documents.map { doc in
                let data = doc.data()
                return TeamMember(
                    uid: doc.documentID,
                    name: data.string("memberName") ?? "",
                    hasAccess: data.bool("access") ?? false,
                    joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue()
                )
            }
        }
    }

    /// Teams [memberUid] is in.
    func observeMemberships(memberUid: String) -> AsyncStream<[TeamMembership]> {
        guard let query = provider.firestore?.collectionGroup("members").whereField("memberUid", isEqualTo: memberUid) else { return .single([]) }
        return query.listen { snapshot in
            snapshot.documents.compactMap { doc in
                let data = doc.data()
                guard let ownerUid = data.string("ownerUid") else { return nil }
                return TeamMembership(
                    ownerUid: ownerUid,
                    ownerName: data.string("ownerName") ?? "",
                    hasAccess: data.bool("access") ?? false,
                    joinedAt: (data["joinedAt"] as? Timestamp)?.dateValue()
                )
            }
        }
    }

    func createInvite(ownerUid: String, ownerName: String, expiresAt: Date) async throws(DataError) -> TeamInvite {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        let invite = TeamInvite(code: Self.newCode(), ownerUid: ownerUid, ownerName: ownerName, expiresAt: expiresAt, isUsed: false)
        try await firestoreRequest {
            try await firestore.collection("invites").document(invite.code).setData([
                "ownerUid": ownerUid,
                "ownerName": ownerName,
                "createdAt": FieldValue.serverTimestamp(),
                "expiresAt": Timestamp(date: expiresAt),
                "usedBy": NSNull(),
            ])
        }
        return invite
    }

    /// nil when there's no invite with [code].
    func getInvite(code: String) async throws(DataError) -> TeamInvite? {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        return try await firestoreRequest {
            let doc = try await firestore.collection("invites").document(code).getDocument()
            guard let data = doc.data(), let ownerUid = data.string("ownerUid") else { return nil }
            return TeamInvite(
                code: code,
                ownerUid: ownerUid,
                ownerName: data.string("ownerName") ?? "",
                expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue() ?? Date(timeIntervalSince1970: 0),
                isUsed: !(data["usedBy"] == nil || data["usedBy"] is NSNull)
            )
        }
    }

    /// Joins the invite's team with access granted, using up the invite in the same write.
    func join(invite: TeamInvite, memberUid: String, memberName: String) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest {
            let batch = firestore.batch()
            batch.setData([
                "memberUid": memberUid,
                "memberName": memberName,
                "ownerUid": invite.ownerUid,
                "ownerName": invite.ownerName,
                "access": true,
                "inviteCode": invite.code,
                "joinedAt": FieldValue.serverTimestamp(),
            ], forDocument: membership(firestore, ownerUid: invite.ownerUid, memberUid: memberUid))
            batch.updateData(["usedBy": memberUid], forDocument: firestore.collection("invites").document(invite.code))
            try await batch.commit()
        }
    }

    func setAccess(ownerUid: String, memberUid: String, access: Bool) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest { try await membership(firestore, ownerUid: ownerUid, memberUid: memberUid).updateData(["access": access]) }
    }

    /// Leaving (by the member) or removing (by the owner).
    func deleteMembership(ownerUid: String, memberUid: String) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest { try await membership(firestore, ownerUid: ownerUid, memberUid: memberUid).delete() }
    }

    /// Writes my new name into the memberships that keep a copy of it: as a member of other teams and as the
    /// owner of mine. Needs the server to find them, so offline it fails and stays as it was.
    func rename(uid: String, name: String) async throws(DataError) {
        guard let firestore = provider.firestore else { throw .network(.unknown) }
        try await firestoreRequest {
            let asMember = try await firestore.collectionGroup("members").whereField("memberUid", isEqualTo: uid).getDocuments(source: .server).documents
            let asOwner = try await firestore.collection("teams").document(uid).collection("members").getDocuments(source: .server).documents
            let batch = firestore.batch()
            asMember.forEach { batch.updateData(["memberName": name], forDocument: $0.reference) }
            asOwner.forEach { batch.updateData(["ownerName": name], forDocument: $0.reference) }
            try await batch.commit()
        }
    }

    private func membership(_ firestore: Firestore, ownerUid: String, memberUid: String) -> DocumentReference {
        firestore.collection("teams").document(ownerUid).collection("members").document(memberUid)
    }

    /// "AK7-29QX": 8 characters without look-alikes (0/O, 1/I/L), about 40 bits, so codes can't be guessed.
    private static func newCode() -> String {
        var generator = SystemRandomNumberGenerator()
        let chars = (0..<8).map { _ in String(codeAlphabet.randomElement(using: &generator)!) }
        return chars[..<3].joined() + "-" + chars[3...].joined()
    }
}

extension AsyncStream where Element: Sendable {
    /// A stream with one value that stays open, so `combineLatest` keeps running with it.
    static func single(_ value: Element) -> AsyncStream<Element> {
        AsyncStream { $0.yield(value) }
    }
}

extension Query {
    /// The query's results, converted by [transform], as they change. Listener callbacks arrive on the main
    /// thread. The stream ends quietly on errors (no access, offline without a cache).
    func listen<T: Sendable>(_ transform: @escaping @MainActor (QuerySnapshot) -> T) -> AsyncStream<T> {
        AsyncStream { continuation in
            let registration = addSnapshotListener { snapshot, _ in
                guard let snapshot else {
                    continuation.finish()
                    return
                }
                continuation.yield(MainActor.assumeIsolated { transform(snapshot) })
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }
}

extension DocumentReference {
    /// The document, converted by [transform], as it changes; [fallback] once after an error (no access).
    func listen<T: Sendable>(fallback: T, _ transform: @escaping @MainActor ([String: Any]?) -> T) -> AsyncStream<T> {
        AsyncStream { continuation in
            let registration = addSnapshotListener { snapshot, _ in
                guard let snapshot else {
                    continuation.yield(fallback)
                    return
                }
                continuation.yield(MainActor.assumeIsolated { transform(snapshot.data()) })
            }
            continuation.onTermination = { _ in registration.remove() }
        }
    }
}

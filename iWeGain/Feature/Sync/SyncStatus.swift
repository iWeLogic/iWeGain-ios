/// Whether this device has what Firestore has ([SyncManager]).
nonisolated enum SyncStatus: Equatable, Sendable {
    /// Loading the signed-in person's data after the app starts; the splash screen waits for it.
    case loading
    /// Everything from the server is on the device, or there's nothing to load (signed out).
    case upToDate
    /// The server couldn't be reached; the app works from local data and keeps retrying.
    case offline
}

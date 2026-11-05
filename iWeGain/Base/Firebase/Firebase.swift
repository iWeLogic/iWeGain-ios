import FirebaseCore
@preconcurrency import FirebaseFirestore
import Foundation

/// Starts Firebase once. Tests and UI tests run without it: every remote data source then has nothing to
/// talk to, sign-in reports `notConfigured`, and the app works locally like it does signed out.
enum AppFirebase {
    static func configureIfPossible() {
        let environment = ProcessInfo.processInfo
        let isTesting = environment.arguments.contains("-ui-testing") || environment.environment["XCTestConfigurationFilePath"] != nil
        guard !isTesting, FirebaseApp.app() == nil, Bundle.main.url(forResource: "GoogleService-Info", withExtension: "plist") != nil else { return }
        FirebaseApp.configure()
    }

    static var isConfigured: Bool { FirebaseApp.app() != nil }
}

/// Firestore, or nil without Firebase. Each person's data lives under `users/{uid}/{collection}`.
final class FirestoreProvider {
    /// Not cached: after clearing its cache a new instance is needed.
    var firestore: Firestore? { AppFirebase.isConfigured ? Firestore.firestore() : nil }

    func userCollection(_ uid: String, _ name: String) -> CollectionReference? {
        firestore?.collection("users").document(uid).collection(name)
    }
}

extension BaseDataSource {
    /// Runs a Firestore call and turns its failures into [DataError]s.
    func firestoreRequest<T>(_ call: () async throws -> T) async throws(DataError) -> T {
        do {
            return try await call()
        } catch is CancellationError {
            throw .network(.cancelled)
        } catch {
            throw .network(Self.firestoreError(error))
        }
    }

    static func firestoreError(_ error: Error) -> DataError.Network {
        let nsError = error as NSError
        guard nsError.domain == FirestoreErrorDomain, let code = FirestoreErrorCode.Code(rawValue: nsError.code) else { return .unknown }
        switch code {
        case .unavailable, .deadlineExceeded: return .noInternet
        case .unauthenticated: return .unauthorized
        case .permissionDenied: return .forbidden
        case .notFound: return .notFound
        case .internal, .dataLoss: return .serverError
        case .cancelled: return .cancelled
        default: return .unknown
        }
    }
}

/// Reads typed fields of a Firestore document (numbers arrive as NSNumber).
nonisolated extension Dictionary where Key == String, Value == Any {
    func string(_ key: String) -> String? { self[key] as? String }
    func int(_ key: String) -> Int? { (self[key] as? NSNumber)?.intValue }
    func int64(_ key: String) -> Int64? { (self[key] as? NSNumber)?.int64Value }
    func double(_ key: String) -> Double? { (self[key] as? NSNumber)?.doubleValue }
    func bool(_ key: String) -> Bool? { (self[key] as? NSNumber)?.boolValue }
    func maps(_ key: String) -> [[String: Any]] { self[key] as? [[String: Any]] ?? [] }
}

/// Firestore's way of storing nil in a map.
nonisolated func orNull(_ value: Any?) -> Any { value ?? NSNull() }

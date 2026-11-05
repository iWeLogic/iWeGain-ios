import CoreData
import Foundation

/// Turns database and network errors into [DataError]s, so data sources never write their own do/catch.
class BaseDataSource {

    init() {}

    func dbRequest<T>(_ call: () throws -> T) throws(DataError) -> T {
        do {
            return try call()
        } catch {
            throw .local(Self.isDiskFull(error) ? .diskFull : .unknown)
        }
    }

    func remoteRequest<T>(_ call: () async throws -> T) async throws(DataError) -> T {
        do {
            return try await call()
        } catch is CancellationError {
            throw .network(.cancelled)
        } catch let error as URLError {
            throw .network(Self.networkError(error))
        } catch {
            throw .network(.unknown)
        }
    }

    static func networkError(_ error: URLError) -> DataError.Network {
        switch error.code {
        case .cancelled: .cancelled
        case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .cannotConnectToHost,
             .dataNotAllowed, .timedOut, .internationalRoamingOff: .noInternet
        case .userAuthenticationRequired: .unauthorized
        case .badServerResponse: .serverError
        default: .unknown
        }
    }

    /// Out of storage, either reported by Foundation or by SQLite (SQLITE_FULL) under SwiftData.
    static func isDiskFull(_ error: Error) -> Bool {
        var current: NSError? = error as NSError
        while let nsError = current {
            if nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileWriteOutOfSpaceError { return true }
            if nsError.domain == NSPOSIXErrorDomain && nsError.code == Int(ENOSPC) { return true }
            if nsError.domain == NSSQLiteErrorDomain && nsError.code == 13 { return true }
            current = nsError.userInfo[NSUnderlyingErrorKey] as? NSError
        }
        return false
    }
}

extension BaseDataSource {
    /// [fetch]'s result now and after every change to [store], skipping repeats (a Room Flow).
    /// A read that fails is skipped; the next change tries again.
    func observe<T: Equatable & Sendable>(_ store: LocalStore, _ fetch: @escaping () throws -> T) -> AsyncStream<T> {
        AsyncStream { continuation in
            let task = Task { @MainActor in
                var last: T?
                for await _ in store.changes() {
                    guard let value = try? fetch(), value != last else { continue }
                    last = value
                    continuation.yield(value)
                }
                continuation.finish()
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}

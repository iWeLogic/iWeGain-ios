import CoreData
import Foundation
import Testing
@testable import iWeGain

@MainActor
struct BaseDataSourceTests {
    private let dataSource = BaseDataSource()

    @Test func dbRequestReturnsTheResult() throws {
        #expect(try dataSource.dbRequest { 42 } == 42)
    }

    @Test func diskFullErrorsBecomeDiskFull() {
        let sqliteFull = NSError(domain: NSCocoaErrorDomain, code: 134_030, userInfo: [
            NSUnderlyingErrorKey: NSError(domain: NSSQLiteErrorDomain, code: 13)
        ])
        #expect(throws: DataError.local(.diskFull)) { try dataSource.dbRequest { () throws -> Int in throw sqliteFull } }
        let outOfSpace = NSError(domain: NSCocoaErrorDomain, code: NSFileWriteOutOfSpaceError)
        #expect(throws: DataError.local(.diskFull)) { try dataSource.dbRequest { () throws -> Int in throw outOfSpace } }
    }

    @Test func otherDatabaseErrorsBecomeUnknown() {
        #expect(throws: DataError.local(.unknown)) {
            try dataSource.dbRequest { () throws -> Int in throw NSError(domain: NSCocoaErrorDomain, code: 134_060) }
        }
    }

    @Test(arguments: [
        (URLError.Code.notConnectedToInternet, DataError.Network.noInternet),
        (.networkConnectionLost, .noInternet),
        (.timedOut, .noInternet),
        (.cancelled, .cancelled),
        (.userAuthenticationRequired, .unauthorized),
        (.badServerResponse, .serverError),
        (.badURL, .unknown),
    ])
    func urlErrorsAreMapped(code: URLError.Code, expected: DataError.Network) async {
        await #expect(throws: DataError.network(expected)) {
            try await dataSource.remoteRequest { () async throws -> Int in throw URLError(code) }
        }
    }

    @Test func cancellationBecomesCancelled() async {
        await #expect(throws: DataError.network(.cancelled)) {
            try await dataSource.remoteRequest { () async throws -> Int in throw CancellationError() }
        }
    }
}

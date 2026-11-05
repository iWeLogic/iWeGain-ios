import Foundation
import Testing
@testable import iWeGain

struct DataErrorMessageTests {

    @Test(arguments: [
        (DataError.network(.noInternet), "error_no_internet"),
        (.network(.unauthorized), "error_not_signed_in"),
        (.network(.forbidden), "error_forbidden"),
        (.network(.notFound), "error_not_found"),
        (.network(.serverError), "error_unknown"),
        (.network(.unknown), "error_unknown"),
        (.local(.diskFull), "error_disk_full"),
        (.local(.notFound), "error_not_found"),
        (.local(.unknown), "error_unknown"),
    ])
    func everyErrorHasAMessage(error: DataError, key: String) throws {
        #expect(try #require(error.message).key == key)
    }

    @Test func cancellationShowsNothing() {
        #expect(DataError.network(.cancelled).message == nil)
    }
}

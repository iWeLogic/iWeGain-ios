import Foundation

extension DataError {
    /// What the user sees for this error; nil shows nothing (cancellation).
    var message: LocalizedStringResource? {
        switch self {
        case .network(.cancelled): nil
        case .network(.noInternet): "error_no_internet"
        case .network(.unauthorized): "error_not_signed_in"
        case .network(.forbidden): "error_forbidden"
        case .network(.notFound), .local(.notFound): "error_not_found"
        case .local(.diskFull): "error_disk_full"
        case .network(.serverError), .network(.unknown), .local(.unknown): "error_unknown"
        }
    }
}

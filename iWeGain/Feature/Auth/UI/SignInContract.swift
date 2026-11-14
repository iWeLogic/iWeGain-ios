import Foundation

struct SignInState: Equatable {
    var isGoogleLoading = false
    var isAppleLoading = false
    var isSigningIn: Bool { isGoogleLoading || isAppleLoading }
}

enum SignInAction {
    case onAppleTap
    case onGoogleTap
    case onCloseTap
}

enum SignInEvent: UiEvent {
    case close
    case showMessage(String)
}

extension AuthError {
    /// nil when the user closed the account picker: nothing to tell them.
    var messageKey: String? {
        switch self {
        case .cancelled: nil
        case .noGoogleAccount: "auth_error_no_google_account"
        case .tooManyRequests: "auth_error_too_many_requests"
        case .noInternet: "auth_error_no_internet"
        case .notConfigured: "auth_error_not_configured"
        case .methodDisabled: "auth_error_method_disabled"
        case .wrongAccount: "auth_error_wrong_account"
        case .accountExists: "auth_error_account_exists"
        case .unknown: "auth_error_unknown"
        }
    }
}

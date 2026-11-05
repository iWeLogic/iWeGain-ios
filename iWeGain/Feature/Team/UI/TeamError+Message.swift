extension TeamError {
    /// String Catalog key of the message to show.
    var messageKey: String {
        switch self {
        case .notSignedIn: "team_error_not_signed_in"
        case .inviteNotFound: "team_error_invite_not_found"
        case .inviteExpired: "team_error_invite_expired"
        case .inviteUsed: "team_error_invite_used"
        case .ownInvite: "team_error_own_invite"
        case .noInternet: "auth_error_no_internet"
        case .unknown: "team_error_unknown"
        }
    }

    var message: String { Strings.text(messageKey) }
}

extension ProfileError {
    /// String Catalog key of the message to show.
    var messageKey: String {
        switch self {
        case .notSignedIn: "team_error_not_signed_in"
        case .photo: "profile_error_photo"
        case .noInternet: "auth_error_no_internet"
        case .unknown: "team_error_unknown"
        }
    }

    var message: String { Strings.text(messageKey) }
}

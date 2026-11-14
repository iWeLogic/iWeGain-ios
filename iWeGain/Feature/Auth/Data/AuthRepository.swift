@preconcurrency import FirebaseAuth
import FirebaseCore
import AuthenticationServices
import Foundation
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Firebase Authentication with Google and Apple. Works without Firebase too: nobody is signed in and sign-in
/// fails with [AuthError.notConfigured].
///
/// One account per email: signing in with a second provider whose email already has an account fails with
/// [AuthError.accountExists]. The credential is kept, and the next successful sign-in (the way the person
/// signed in before) links it, so after that both providers open the same account.
final class AuthRepository {
    private let userState = StateStream<AuthUser?>(nil)
    private var listener: AuthStateDidChangeListenerHandle?
    /// The other provider's credential, waiting to be linked after the next sign-in.
    private var pendingLink: AuthCredential?
    /// From the last Apple re-authentication: [deleteUser] revokes the app's Apple tokens with it.
    private var appleAuthorizationCode: String?

    init() {
        guard AppFirebase.isConfigured else { return }
        let auth = Auth.auth()
        userState.send(auth.currentUser.map(Self.authUser))
        listener = auth.addStateDidChangeListener { [weak self] _, user in
            self?.userState.send(user.map(Self.authUser))
        }
    }

    var isConfigured: Bool { AppFirebase.isConfigured }
    var currentUser: AuthUser? { userState.value }

    func observeUser() -> AsyncStream<AuthUser?> { userState.stream() }

    func signInWithGoogle() async throws(AuthError) {
        guard isConfigured else { throw .notConfigured }
        try await signIn(with: try await googleCredential())
    }

    func signInWithApple() async throws(AuthError) {
        guard isConfigured else { throw .notConfigured }
        let apple = try await appleCredential()
        try await signIn(with: apple.firebase)
        // Apple gives the name only on the first sign-in, and Firebase doesn't keep it.
        if let user = Auth.auth().currentUser, user.displayName?.nonBlank == nil, let name = apple.name {
            let change = user.createProfileChangeRequest()
            change.displayName = name
            try? await change.commitChanges()
            userState.send(Self.authUser(user))
        }
    }

    /// Confirms the signed-in account again with the provider it uses (Google first when both are linked).
    /// Firebase only deletes an account that signed in a few minutes ago; picking another account fails with
    /// [AuthError.wrongAccount].
    func reauthenticate() async throws(AuthError) {
        guard isConfigured, let user = Auth.auth().currentUser else { throw .unknown }
        switch Self.signInProvider(of: user) {
        case .google:
            let credential = try await googleCredential()
            try await firebaseCall { _ = try await user.reauthenticate(with: credential) }
        case .apple:
            let apple = try await appleCredential()
            try await firebaseCall { _ = try await user.reauthenticate(with: apple.firebase) }
            appleAuthorizationCode = apple.authorizationCode
        case nil:
            throw .unknown
        }
    }

    /// Deletes the signed-in Firebase account; afterwards no one is signed in. An Apple account first revokes
    /// the app's Apple tokens (App Store rule), when [reauthenticate] got a code for that.
    func deleteUser() async throws(AuthError) {
        guard isConfigured, let user = Auth.auth().currentUser else { throw .unknown }
        if let code = appleAuthorizationCode {
            appleAuthorizationCode = nil
            // Not worth keeping the account for: it fails when the Apple provider has no key in Firebase.
            try? await Auth.auth().revokeToken(withAuthorizationCode: code)
        }
        try await firebaseCall { try await user.delete() }
    }

    func signOut() {
        guard isConfigured else { return }
        pendingLink = nil
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
    }

    /// Signs in, then links a credential an earlier attempt left for this account.
    private func signIn(with credential: AuthCredential) async throws(AuthError) {
        do {
            _ = try await Auth.auth().signIn(with: credential)
        } catch {
            let nsError = error as NSError
            if nsError.domain == AuthErrorDomain, nsError.code == AuthErrorCode.accountExistsWithDifferentCredential.rawValue,
               let pending = nsError.userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential {
                pendingLink = pending
                throw .accountExists
            }
            throw Self.authError(error)
        }
        if let pending = pendingLink, let user = Auth.auth().currentUser {
            pendingLink = nil
            // A failure (e.g. a different account) only means the providers stay separate.
            _ = try? await user.link(with: pending)
        }
    }

    /// The Google sign-in web page coming back to the app.
    func handle(url: URL) -> Bool {
        GIDSignIn.sharedInstance.handle(url)
    }

    private func googleCredential() async throws(AuthError) -> AuthCredential {
        guard let clientId = FirebaseApp.app()?.options.clientID, let presenter = Self.presenter else { throw .notConfigured }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
            guard let idToken = result.user.idToken?.tokenString else { throw AuthError.unknown }
            return GoogleAuthProvider.credential(withIDToken: idToken, accessToken: result.user.accessToken.tokenString)
        } catch let error as AuthError {
            throw error
        } catch {
            let nsError = error as NSError
            if nsError.domain == kGIDSignInErrorDomain && nsError.code == GIDSignInError.canceled.rawValue { throw .cancelled }
            throw (nsError.domain == NSURLErrorDomain ? .noInternet : .unknown)
        }
    }

    private struct AppleCredential {
        let firebase: AuthCredential
        let name: String?
        let authorizationCode: String?
    }

    private func appleCredential() async throws(AuthError) -> AppleCredential {
        let result: AppleSignIn.Result
        do {
            result = try await AppleSignIn().perform()
        } catch {
            let nsError = error as NSError
            if nsError.domain == ASAuthorizationError.errorDomain && nsError.code == ASAuthorizationError.canceled.rawValue { throw .cancelled }
            throw (nsError.domain == NSURLErrorDomain ? .noInternet : .unknown)
        }
        guard let tokenData = result.credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else { throw .unknown }
        let fullName = result.credential.fullName
        let name = fullName.map { PersonNameComponentsFormatter().string(from: $0) }?.nonBlank
        return AppleCredential(
            firebase: OAuthProvider.appleCredential(withIDToken: idToken, rawNonce: result.rawNonce, fullName: fullName),
            name: name,
            authorizationCode: result.credential.authorizationCode.flatMap { String(data: $0, encoding: .utf8) }
        )
    }

    private static func signInProvider(of user: FirebaseAuth.User) -> SignInProvider? {
        let ids = Set(user.providerData.map(\.providerID))
        if ids.contains(GoogleAuthProviderID) { return .google }
        if ids.contains("apple.com") { return .apple }
        return nil
    }

    private func firebaseCall(_ call: () async throws -> Void) async throws(AuthError) {
        do {
            try await call()
        } catch {
            throw Self.authError(error)
        }
    }

    static func authError(_ error: Error) -> AuthError {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain, let code = AuthErrorCode(rawValue: nsError.code) else { return .unknown }
        switch code {
        case .networkError: return .noInternet
        case .tooManyRequests: return .tooManyRequests
        case .operationNotAllowed, .appNotAuthorized: return .methodDisabled
        case .userMismatch: return .wrongAccount
        default: return .unknown
        }
    }

    private static func authUser(_ user: FirebaseAuth.User) -> AuthUser {
        AuthUser(
            id: user.uid,
            name: user.displayName?.nonBlank,
            email: user.email?.nonBlank,
            phoneNumber: user.phoneNumber?.nonBlank,
            createdAt: user.metadata.creationDate,
            photoUrl: user.photoURL,
            provider: signInProvider(of: user)
        )
    }

    #if canImport(UIKit)
    private static var presenter: UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var top = scenes.flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    #elseif canImport(AppKit)
    private static var presenter: NSWindow? { NSApplication.shared.keyWindow }
    #endif
}

nonisolated extension String {
    /// nil when there is nothing but white space.
    var nonBlank: String? { trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : self }
}

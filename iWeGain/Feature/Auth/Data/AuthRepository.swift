@preconcurrency import FirebaseAuth
import FirebaseCore
import Foundation
import GoogleSignIn
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Firebase Authentication with Google. Works without Firebase too: nobody is signed in and sign-in
/// fails with [AuthError.notConfigured].
final class AuthRepository {
    private let userState = StateStream<AuthUser?>(nil)
    private var listener: AuthStateDidChangeListenerHandle?

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
        let credential = try await googleCredential()
        try await firebaseCall { _ = try await Auth.auth().signIn(with: credential) }
    }

    /// Asks for the signed-in Google account again. Firebase only deletes an account that signed in a few
    /// minutes ago; picking another account fails with [AuthError.wrongAccount].
    func reauthenticateWithGoogle() async throws(AuthError) {
        guard isConfigured, let user = Auth.auth().currentUser else { throw .unknown }
        let credential = try await googleCredential()
        try await firebaseCall { _ = try await user.reauthenticate(with: credential) }
    }

    /// Deletes the signed-in Firebase account; afterwards no one is signed in.
    func deleteUser() async throws(AuthError) {
        guard isConfigured, let user = Auth.auth().currentUser else { throw .unknown }
        try await firebaseCall { try await user.delete() }
    }

    func signOut() {
        guard isConfigured else { return }
        try? Auth.auth().signOut()
        GIDSignIn.sharedInstance.signOut()
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
            photoUrl: user.photoURL
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

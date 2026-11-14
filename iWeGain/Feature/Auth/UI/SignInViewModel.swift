final class SignInViewModel: BaseViewModel<SignInState, SignInAction, SignInEvent> {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        super.init(initialState: SignInState())
    }

    override func onAction(_ action: SignInAction) {
        switch action {
        case .onCloseTap: sendEvent(.close)
        case .onGoogleTap: signIn(loading: \.isGoogleLoading) { [authRepository] () async throws(AuthError) in try await authRepository.signInWithGoogle() }
        case .onAppleTap: signIn(loading: \.isAppleLoading) { [authRepository] () async throws(AuthError) in try await authRepository.signInWithApple() }
        }
    }

    private func signIn(loading: WritableKeyPath<SignInState, Bool>, _ call: @escaping () async throws(AuthError) -> Void) {
        guard !state.isSigningIn else { return }
        launch { [self] in
            updateState { $0[keyPath: loading] = true }
            do throws(AuthError) {
                try await call()
                sendEvent(.close)
            } catch {
                if let key = error.messageKey { sendEvent(.showMessage(Strings.text(key))) }
            }
            updateState { $0[keyPath: loading] = false }
        }
    }
}

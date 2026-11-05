final class SignInViewModel: BaseViewModel<SignInState, SignInAction, SignInEvent> {
    private let authRepository: AuthRepository

    init(authRepository: AuthRepository) {
        self.authRepository = authRepository
        super.init(initialState: SignInState())
    }

    override func onAction(_ action: SignInAction) {
        switch action {
        case .onCloseTap: sendEvent(.close)
        case .onGoogleTap:
            guard !state.isGoogleLoading else { return }
            launch { [self] in
                updateState { $0.isGoogleLoading = true }
                do throws(AuthError) {
                    try await authRepository.signInWithGoogle()
                    sendEvent(.close)
                } catch {
                    if let key = error.messageKey { sendEvent(.showMessage(Strings.text(key))) }
                }
                updateState { $0.isGoogleLoading = false }
            }
        }
    }
}

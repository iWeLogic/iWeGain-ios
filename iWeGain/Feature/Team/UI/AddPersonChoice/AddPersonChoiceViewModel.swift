/// "Add a person": create a profile inside my account, or invite someone with their own account.
final class AddPersonChoiceViewModel: BaseViewModel<AddPersonChoiceState, AddPersonChoiceAction, AddPersonChoiceEvent> {
    private let userRepository: UserRepository
    private var isObserving = false

    init(userRepository: UserRepository) {
        self.userRepository = userRepository
        super.init(initialState: AddPersonChoiceState())
    }

    override func onAction(_ action: AddPersonChoiceAction) {
        switch action {
        case .onAppear: observe()
        case .onCloseTap: sendEvent(.close)
        case .onCreateProfileTap:
            if state.isSignedIn { sendEvent(.navigateToCreateProfile) }
        case .onInviteTap:
            if state.isSignedIn { sendEvent(.navigateToInvite) }
        case .onSignInTap: sendEvent(.navigateToSignIn)
        }
    }

    /// Signing in from here comes back to this screen with the options enabled.
    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        let me = userRepository.observeMe()
        launch { [weak self] in
            for await me in me {
                self?.updateState {
                    $0.me = me.toUserUi(isSelected: true)
                    $0.isSignedIn = !me.isGuest
                }
            }
        }
    }
}

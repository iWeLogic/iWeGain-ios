/// Creates a one-person invite to my team (valid for 7 days) and shares its link.
final class AddPersonViewModel: BaseViewModel<AddPersonState, AddPersonAction, AddPersonEvent> {
    private let teamRepository: TeamRepository
    private let userRepository: UserRepository
    private var isObserving = false

    init(teamRepository: TeamRepository, userRepository: UserRepository) {
        self.teamRepository = teamRepository
        self.userRepository = userRepository
        super.init(initialState: AddPersonState())
    }

    override func onAction(_ action: AddPersonAction) {
        switch action {
        case .onAppear: observe()
        case .onCloseTap: sendEvent(.close)
        case .onCopyTap:
            if let link = state.link { sendEvent(.copyLink(link)) }
        case .onRetryTap: createInvite()
        case .onSignInTap: sendEvent(.navigateToSignIn)
        }
    }

    /// Signing in from this screen comes back here, and the invite is created then.
    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        let me = userRepository.observeMe()
        launch { [weak self] in
            for await me in me {
                self?.show(me)
            }
        }
    }

    private func show(_ me: User) {
        updateState {
            $0.me = me.toUserUi(isSelected: true)
            $0.isSignedIn = !me.isGuest
        }
        if !me.isGuest && state.link == nil && !state.isCreating { createInvite() }
    }

    private func createInvite() {
        updateState {
            $0.isCreating = true
            $0.error = nil
        }
        launch { [self] in
            do throws(TeamError) {
                let invite = try await teamRepository.createInvite()
                updateState { $0.link = invite.link }
            } catch {
                updateState { $0.error = error.message }
            }
            updateState { $0.isCreating = false }
        }
    }
}

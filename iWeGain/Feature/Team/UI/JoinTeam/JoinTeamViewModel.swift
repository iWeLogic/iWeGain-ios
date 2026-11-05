/// Opened from an invite link. Signed out it asks to sign in first ("Alex Kim invited you"); signed in it asks
/// to join the team, which allows the owner to see and change my data.
final class JoinTeamViewModel: BaseViewModel<JoinTeamState, JoinTeamAction, JoinTeamEvent> {
    private let code: String
    private let teamRepository: TeamRepository
    private let authRepository: AuthRepository
    private var isObserving = false
    private var invite: TeamInvite?

    init(code: String, teamRepository: TeamRepository, authRepository: AuthRepository) {
        self.code = code
        self.teamRepository = teamRepository
        self.authRepository = authRepository
        super.init(initialState: JoinTeamState())
    }

    override func onAction(_ action: JoinTeamAction) {
        switch action {
        case .onAppear: observe()
        case .onJoinTap: join()
        case .onNotNowTap: sendEvent(.close)
        case .onGoogleTap: signInWithGoogle()
        }
    }

    /// Signing in with Google here comes back to this screen; the invite is checked again then, e.g. to catch my own invite.
    private func observe() {
        guard !isObserving else { return }
        isObserving = true
        let signedIn = authRepository.observeUser().map { $0 != nil }.removeDuplicates()
        launch { [weak self] in
            for await isSignedIn in signedIn {
                self?.updateState { $0.isSignedIn = isSignedIn }
                await self?.loadInvite()
            }
        }
    }

    private func loadInvite() async {
        updateState { $0.isLoading = true }
        do throws(TeamError) {
            let invite = try await teamRepository.getInvite(code: code)
            self.invite = invite
            updateState {
                $0.ownerName = invite.ownerName
                $0.ownerInitials = User.initials(of: invite.ownerName)
                $0.error = nil
            }
        } catch {
            updateState { $0.error = error.message }
        }
        updateState { $0.isLoading = false }
    }

    private func signInWithGoogle() {
        guard !state.isSigningIn else { return }
        launch { [self] in
            updateState { $0.isSigningIn = true }
            do throws(AuthError) {
                try await authRepository.signInWithGoogle()
            } catch {
                if let key = error.messageKey { sendEvent(.showMessage(Strings.text(key))) }
            }
            updateState { $0.isSigningIn = false }
        }
    }

    private func join() {
        guard let invite, !state.isJoining else { return }
        launch { [self] in
            updateState { $0.isJoining = true }
            do throws(TeamError) {
                try await teamRepository.join(invite)
                sendEvent(.close)
            } catch {
                updateState { $0.error = error.message }
            }
            updateState { $0.isJoining = false }
        }
    }
}

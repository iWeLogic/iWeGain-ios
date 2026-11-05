extension AppContainer {
    var teamRepository: TeamRepository {
        shared { TeamRepository(authRepository: authRepository, remote: TeamRemoteDataSource(provider: firestore), now: store.now) }
    }

    func makeMyTeamViewModel() -> MyTeamViewModel {
        MyTeamViewModel(teamRepository: teamRepository, profileRepository: profileRepository, userRepository: userRepository)
    }

    func makeJoinTeamViewModel(code: String) -> JoinTeamViewModel {
        JoinTeamViewModel(code: code, teamRepository: teamRepository, authRepository: authRepository)
    }

    func makeAddPersonChoiceViewModel() -> AddPersonChoiceViewModel {
        AddPersonChoiceViewModel(userRepository: userRepository)
    }

    func makeAddPersonViewModel() -> AddPersonViewModel {
        AddPersonViewModel(teamRepository: teamRepository, userRepository: userRepository)
    }

    func makeTeamsImInViewModel() -> TeamsImInViewModel {
        TeamsImInViewModel(teamRepository: teamRepository)
    }
}

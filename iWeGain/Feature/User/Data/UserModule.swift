extension AppContainer {
    var userRepository: UserRepository {
        shared {
            UserRepository(
                local: UserLocalDataSource(defaults: defaults, store: store),
                authRepository: authRepository,
                teamRepository: teamRepository,
                profileRepository: profileRepository
            )
        }
    }
}

extension AppContainer {
    var profileRepository: ProfileRepository {
        shared {
            ProfileRepository(
                authRepository: authRepository,
                remote: ProfileRemoteDataSource(provider: firestore),
                accountRemote: AccountRemoteDataSource(provider: firestore),
                teamRepository: teamRepository
            )
        }
    }

    func makeProfileEditorViewModel(mode: ProfileEditorMode) -> ProfileEditorViewModel {
        ProfileEditorViewModel(mode: mode, profileRepository: profileRepository, userRepository: userRepository)
    }
}

extension AppContainer {
    var settingsRepository: SettingsRepository {
        shared {
            SettingsRepository(
                local: SettingsLocalDataSource(defaults: defaults, store: store),
                authRepository: authRepository,
                remote: SettingsRemoteDataSource(provider: firestore)
            )
        }
    }
}

extension AppContainer {
    func makeSettingsViewModel() -> SettingsViewModel {
        SettingsViewModel(
            settingsRepository: settingsRepository,
            authRepository: authRepository,
            accountRepository: accountRepository,
            teamRepository: teamRepository,
            profileRepository: profileRepository
        )
    }
}

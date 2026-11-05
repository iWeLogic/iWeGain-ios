extension AppContainer {
    var authRepository: AuthRepository { shared { AuthRepository() } }

    var accountRepository: AccountRepository {
        AccountRepository(
            authRepository: authRepository,
            syncManager: syncManager,
            deviceDataSource: deviceDataSource,
            pushRepository: pushRepository,
            settingsRepository: settingsRepository,
            remote: AccountRemoteDataSource(provider: firestore),
            network: network
        )
    }

    func makeSignInViewModel() -> SignInViewModel {
        SignInViewModel(authRepository: authRepository)
    }
}

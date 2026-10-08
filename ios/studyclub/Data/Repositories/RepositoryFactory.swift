enum RepositoryFactory {
    @MainActor
    static func makeAccountRepository() -> any AccountRepository {
        #if DEBUG
        if DevelopmentSettingsStore().repositoryMode == .mock {
            return MockAccountRepository()
        }
        #endif
        return makeLiveAccountRepository(accessToken: nil)
    }

    @MainActor
    static func makeLiveAccountRepository(
        accessToken: String?,
        refreshToken: String? = nil
    ) -> any AccountRepository {
        LiveAccountRepository(accessToken: accessToken, refreshToken: refreshToken)
    }

    static func makeStudyRepository() -> any RepositoryProtocol {
        #if DEBUG
        if DevelopmentSettingsStore().repositoryMode == .mock {
            return MockRepository()
        }
        #endif
        return Repository()
    }

    static func makeListRepository() -> any RepositoryProtocol {
        makeStudyRepository()
    }

    static func makeDetailRepository() -> any RepositoryProtocol {
        makeStudyRepository()
    }
}

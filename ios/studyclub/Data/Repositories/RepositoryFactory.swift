enum RepositoryFactory {
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

    /// A new repository each call. `SettingAccountViewModel` owns the one instance that login and
    /// onboarding share for that feature lifetime. Debug follows the saved Mock/Real mode; Release
    /// always uses the real repository. The feature flag does not choose the type.
    static func makeAuthRepository() -> any AuthRepository {
        #if DEBUG
        if DevelopmentSettingsStore().repositoryMode == .mock {
            return MockAuthRepository(
                isFeatureEnabled: { DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition) }
            )
        }
        #endif
        return DefaultAuthRepository()
    }
}

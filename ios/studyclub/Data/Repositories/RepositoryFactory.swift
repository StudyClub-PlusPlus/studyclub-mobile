enum RepositoryFactory {
    /// Concrete root-local graph for the actual account and private-list consumers.
    struct MemberRepositories {
        let auth: any AuthRepository
        let studies: any RepositoryProtocol
        let isMock: Bool
    }

    static func makeMemberRepositories() -> MemberRepositories {
        #if DEBUG
        if DevelopmentSettingsStore().repositoryMode == .mock {
            return MemberRepositories(
                auth: MockAuthRepository(isFeatureEnabled: { DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition) }),
                studies: MockRepository(),
                isMock: true
            )
        }
        #endif
        let auth = DefaultAuthRepository()
        return MemberRepositories(
            auth: auth,
            studies: Repository(
                authorization: auth,
                isMyStudiesAPIEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.myStudies.definition)
            ),
            isMock: false
        )
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

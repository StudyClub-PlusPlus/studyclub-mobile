enum RepositoryFactory {
    static func makeStudyRepository() -> any RepositoryProtocol {
        Repository()
    }

    static func makeDetailRepository() -> any RepositoryProtocol {
        makeStudyRepository()
    }

    static func makeFeatureFlagStore() -> any FeatureFlagStoring {
        UserDefaultsFeatureFlagStore(defaults: .standard)
    }
}

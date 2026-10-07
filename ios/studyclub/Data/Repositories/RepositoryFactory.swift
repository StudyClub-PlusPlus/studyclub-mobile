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
}

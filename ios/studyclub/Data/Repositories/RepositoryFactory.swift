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
        if !DevelopmentSettingsStore().isEnabled(FeatureFlag.studyListAPI.definition) {
            return MockRepository()
        }
        return makeStudyRepository()
    }

    static func makeDetailRepository() -> any RepositoryProtocol {
        let settings = DevelopmentSettingsStore()
        // List-OFF cards carry sample IDs, so their detail must stay in the sample catalog.
        if !settings.isEnabled(FeatureFlag.studyListAPI.definition)
            || !settings.isEnabled(FeatureFlag.studyDetailAPI.definition) {
            return MockRepository()
        }
        return makeStudyRepository()
    }
}

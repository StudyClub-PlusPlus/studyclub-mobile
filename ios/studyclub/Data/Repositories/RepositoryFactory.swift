import Foundation

enum RepositoryFactory {
    static func makeStudyRepository() -> any RepositoryProtocol {
        #if DEBUG
        return makeStudyRepository(mode: makeRepositoryModeStore().mode)
        #else
        return makeStudyRepository(mode: .defaultMode)
        #endif
    }

    static func makeStudyRepository(
        mode: RepositoryMode,
        scenario: MockStudyScenario = .content
    ) -> any RepositoryProtocol {
        if mode == .real { return Repository(client: AlamofireStudyAPIClient()) }
        return Repository(client: MockStudyAPIClient(scenario: scenario))
    }

    static func makeDetailRepository(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any RepositoryProtocol {
        let featureFlagStore = makeFeatureFlagStore()
        guard featureFlagStore.isEnabled(FeatureFlag.studyDetailAPI.definition) else {
            return makeStudyRepository(mode: .mock, arguments: arguments)
        }
        return makeStudyRepository(arguments: arguments)
    }

    static func makeLiveStudyRepository(baseURL: URL) -> any RepositoryProtocol {
        let client = AlamofireStudyAPIClient(baseURL: baseURL)
        return Repository(client: client)
    }

    static func makeRepositoryModeStore() -> any RepositoryModeStoring {
        UserDefaultsRepositoryModeStore(defaults: .standard)
    }

    static func makeFeatureFlagStore() -> any FeatureFlagStoring {
        UserDefaultsFeatureFlagStore(defaults: .standard)
    }
}

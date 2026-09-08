import Foundation

enum RepositoryFactory {
    static func makeStudyRepository(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any RepositoryProtocol {
        #if DEBUG
        // Deterministic UI scenarios override saved developer settings for that launch only.
        let mode: RepositoryMode = arguments.contains("--mock-scenario") ? .mock : makeRepositoryModeStore().mode
        #else
        let mode = RepositoryMode.defaultMode
        #endif
        return makeStudyRepository(mode: mode, arguments: arguments)
    }

    static func makeStudyRepository(mode: RepositoryMode, arguments: [String] = []) -> any RepositoryProtocol {
        if mode == .real { return Repository(client: AlamofireStudyAPIClient()) }
        let scenario = mockScenario(from: arguments)
        let client = MockStudyAPIClient(scenario: scenario)
        return Repository(client: client)
    }

    static func makeLiveStudyRepository(baseURL: URL) -> any RepositoryProtocol {
        let client = AlamofireStudyAPIClient(baseURL: baseURL)
        return Repository(client: client)
    }

    static func makeRepositoryModeStore() -> any RepositoryModeStoring {
        UserDefaultsRepositoryModeStore(defaults: makeDevelopmentDefaults())
    }

    static func makeFeatureFlagStore() -> any FeatureFlagStoring {
        UserDefaultsFeatureFlagStore(defaults: makeDevelopmentDefaults())
    }

    private static func makeDevelopmentDefaults() -> UserDefaults {
        #if DEBUG
        // UI tests use an isolated persistent suite; ordinary app launches use standard defaults.
        if let suite = ProcessInfo.processInfo.environment["STUDYCLUB_UI_TEST_SUITE"],
           suite.hasPrefix("studyclub.ui-tests."), let defaults = UserDefaults(suiteName: suite) {
            return defaults
        }
        #endif
        return .standard
    }

    private static func mockScenario(from arguments: [String]) -> MockStudyScenario {
        guard
            let flagIndex = arguments.firstIndex(of: "--mock-scenario"),
            arguments.indices.contains(flagIndex + 1),
            let scenario = MockStudyScenario(rawValue: arguments[flagIndex + 1])
        else {
            return .content
        }
        return scenario
    }
}

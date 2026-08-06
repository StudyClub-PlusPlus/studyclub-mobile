import Foundation

enum RepositoryFactory {
    static func makeStudyRepository(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any StudyRepository {
        let scenario = mockScenario(from: arguments)
        let client = MockStudyAPIClient(scenario: scenario)
        return DefaultStudyRepository(client: client)
    }

    static func makeLiveStudyRepository(baseURL: URL) -> any StudyRepository {
        let client = AlamofireStudyAPIClient(baseURL: baseURL)
        return DefaultStudyRepository(client: client)
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

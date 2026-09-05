import Foundation

enum RepositoryFactory {
    static func makeStudyRepository(
        arguments: [String] = ProcessInfo.processInfo.arguments
    ) -> any RepositoryProtocol {
        let scenario = mockScenario(from: arguments)
        let client = MockStudyAPIClient(scenario: scenario)
        return Repository(client: client)
    }

    static func makeLiveStudyRepository(baseURL: URL) -> any RepositoryProtocol {
        let client = AlamofireStudyAPIClient(baseURL: baseURL)
        return Repository(client: client)
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

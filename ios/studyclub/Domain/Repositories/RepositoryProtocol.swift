import Foundation

protocol RepositoryProtocol: Sendable {
    func fetchStudies(offset: Int) async throws -> StudyPage
    func searchStudies(query: StudySearchQuery, offset: Int) async throws -> StudyPage
    func fetchStudy(id: Study.ID) async throws -> StudyDetail
    func fetchMyStudies() async throws -> [MyStudy]
}

enum RepositoryError: Error, Equatable, Sendable {
    case featureUnavailable
    case unavailable
    case notFound
    case invalidData
    case unauthorized
    case onboardingRequired
}

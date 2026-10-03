import Foundation

protocol RepositoryProtocol: Sendable {
    func fetchStudies(offset: Int) async throws -> StudyPage
    func fetchStudy(id: Study.ID) async throws -> StudyDetail
}

enum RepositoryError: Error, Equatable, Sendable {
    case unavailable
    case notFound
    case invalidData
}

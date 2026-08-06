import Foundation

protocol StudyRepository: Sendable {
    func fetchStudies() async throws -> [Study]
}

enum StudyRepositoryError: Error, Equatable, Sendable {
    case unavailable
    case invalidData
}

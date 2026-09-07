import Foundation

protocol RepositoryProtocol: Sendable {
    func fetchStudies() async throws -> [Study]
    func fetchStudy(id: Study.ID) async throws -> Study
}

enum RepositoryError: Error, Equatable, Sendable {
    case unavailable
    case invalidData
    case detailAPIUnconfigured
}

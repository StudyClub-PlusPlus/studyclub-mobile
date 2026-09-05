import Foundation

protocol RepositoryProtocol: Sendable {
    func fetchStudies() async throws -> [Study]
}

enum RepositoryError: Error, Equatable, Sendable {
    case unavailable
    case invalidData
}

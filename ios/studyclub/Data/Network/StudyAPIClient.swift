import Foundation

protocol StudyAPIClient: Sendable {
    func fetchStudies() async throws -> [StudyDTO]
}

import Foundation

protocol StudyAPIClient: Sendable {
    func fetchStudies() async throws -> [StudyDTO]
    func fetchStudy(id: Study.ID) async throws -> StudyDTO
}

import Foundation

struct Repository: RepositoryProtocol {
    private let client: StudyAPIClient

    init(client: StudyAPIClient) {
        self.client = client
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        do {
            let study = try await client.fetchStudy(id: id).toDomain()
            try Task.checkCancellation()
            try validateStudyID(study, expectedID: id)
            return study
        } catch {
            throw mapRepositoryError(error)
        }
    }

    func fetchStudies() async throws -> [Study] {
        do {
            let studies = try await client.fetchStudies().map { try $0.toDomain() }
            try validateUniqueStudyIDs(studies)
            return studies
        } catch {
            throw mapRepositoryError(error)
        }
    }
}

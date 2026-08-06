import Foundation

struct DefaultStudyRepository: StudyRepository {
    private let client: any StudyAPIClient

    init(client: any StudyAPIClient) {
        self.client = client
    }

    func fetchStudies() async throws -> [Study] {
        do {
            let studies = try await client.fetchStudies().map { try $0.toDomain() }
            guard Set(studies.map(\.id)).count == studies.count else {
                throw StudyRepositoryError.invalidData
            }
            return studies
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as StudyRepositoryError {
            throw error
        } catch {
            throw StudyRepositoryError.unavailable
        }
    }
}

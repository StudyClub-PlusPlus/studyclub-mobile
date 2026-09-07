import Foundation

struct Repository: RepositoryProtocol {
    private let client: any StudyAPIClient

    init(client: any StudyAPIClient) {
        self.client = client
    }

    func fetchStudy(id: Study.ID) async throws -> Study {
        do {
            let study = try await client.fetchStudy(id: id).toDomain()
            try Task.checkCancellation()
            guard study.id == id else { throw RepositoryError.invalidData }
            return study
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.unavailable
        }
    }

    func fetchStudies() async throws -> [Study] {
        do {
            let studies = try await client.fetchStudies().map { try $0.toDomain() }
            guard Set(studies.map(\.id)).count == studies.count else {
                throw RepositoryError.invalidData
            }
            return studies
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as RepositoryError {
            throw error
        } catch {
            throw RepositoryError.unavailable
        }
    }
}

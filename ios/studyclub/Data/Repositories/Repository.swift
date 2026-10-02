import Alamofire

struct Repository: RepositoryProtocol {
    private let client = StudyAPIClient()

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        do {
            let study = try await client.fetchStudy(id: id).toDomain()
            try Task.checkCancellation()
            try Self.validateStudyID(study, expectedID: id)
            return study
        } catch {
            throw Self.mapError(error)
        }
    }

    func fetchStudies() async throws -> [Study] {
        do {
            let studies = try await client.fetchStudies().map { try $0.toDomain() }
            try Self.validateUniqueStudyIDs(studies)
            return studies
        } catch {
            throw Self.mapError(error)
        }
    }
}

extension Repository {
    static func mapError(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let afError = error as? AFError, afError.isExplicitlyCancelledError {
            return CancellationError()
        }
        if let repositoryError = error as? RepositoryError { return repositoryError }
        return RepositoryError.unavailable
    }

    static func validateUniqueStudyIDs(_ studies: [Study]) throws {
        guard Set(studies.map(\.id)).count == studies.count else {
            throw RepositoryError.invalidData
        }
    }

    static func validateStudyID(_ study: Study, expectedID: Study.ID) throws {
        guard study.id == expectedID else {
            throw RepositoryError.invalidData
        }
    }
}

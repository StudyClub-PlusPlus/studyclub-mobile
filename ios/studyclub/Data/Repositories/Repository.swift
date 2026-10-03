import Alamofire

struct Repository: RepositoryProtocol {
    private let client = StudyAPIClient()

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        do {
            let study = try await client.fetchStudy(id: id).toDomain()
            try Task.checkCancellation()
            try validateStudyID(study, expectedID: id)
            return study
        } catch {
            throw mapError(error)
        }
    }

    func fetchStudies() async throws -> [Study] {
        do {
            let studies = try await client.fetchStudies().map { try $0.toDomain() }
            try validateUniqueStudyIDs(studies)
            return studies
        } catch {
            throw mapError(error)
        }
    }
}

extension Repository {
    func mapError(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let afError = error as? AFError, afError.isExplicitlyCancelledError {
            return CancellationError()
        }
        if let repositoryError = error as? RepositoryError { return repositoryError }
        if let afError = error as? AFError {
            if afError.responseCode == 404 { return RepositoryError.notFound }
            if afError.underlyingError is DecodingError { return RepositoryError.invalidData }
        }
        if error is DecodingError { return RepositoryError.invalidData }
        return RepositoryError.unavailable
    }

    func validateUniqueStudyIDs(_ studies: [Study]) throws {
        guard Set(studies.map(\.id)).count == studies.count else {
            throw RepositoryError.invalidData
        }
    }

    func validateStudyID(_ study: StudyDetail, expectedID: Study.ID) throws {
        guard study.id == expectedID else {
            throw RepositoryError.invalidData
        }
    }
}

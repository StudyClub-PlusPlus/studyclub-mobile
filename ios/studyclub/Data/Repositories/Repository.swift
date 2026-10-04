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

    func fetchStudies(offset: Int) async throws -> StudyPage {
        let limit = 20
        do {
            guard offset >= 0, offset <= Int(Int32.max) else {
                throw RepositoryError.invalidData
            }
            let response = try await client.fetchStudies(offset: offset, limit: limit)
            try Task.checkCancellation()
            try validatePage(response, expectedOffset: offset)
            let studies = response.items.map { $0.toDomain() }
            return StudyPage(studies: studies, totalCount: response.total, offset: response.offset)
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

    func validatePage(_ response: StudyListResponseDTO, expectedOffset: Int) throws {
        guard response.offset == expectedOffset else {
            throw RepositoryError.invalidData
        }
    }

    func validateStudyID(_ study: StudyDetail, expectedID: Study.ID) throws {
        guard study.id == expectedID else {
            throw RepositoryError.invalidData
        }
    }
}

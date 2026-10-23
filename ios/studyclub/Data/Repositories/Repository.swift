import Alamofire
import Foundation

struct Repository: RepositoryProtocol {
    private let client = StudyAPIClient()
    private let authorization: DefaultAuthRepository?
    private let isListAPIEnabled: Bool
    private let isDetailAPIEnabled: Bool
    private let isMyStudiesAPIEnabled: Bool

    init(
        isListAPIEnabled: Bool = DevelopmentSettingsStore().isEnabled(FeatureFlag.studyListAPI.definition),
        isDetailAPIEnabled: Bool = DevelopmentSettingsStore().isEnabled(FeatureFlag.studyDetailAPI.definition),
        authorization: DefaultAuthRepository? = nil,
        isMyStudiesAPIEnabled: Bool = DevelopmentSettingsStore().isEnabled(FeatureFlag.myStudies.definition)
    ) {
        self.isListAPIEnabled = isListAPIEnabled
        self.isDetailAPIEnabled = isDetailAPIEnabled
        self.authorization = authorization
        self.isMyStudiesAPIEnabled = isMyStudiesAPIEnabled
    }

    func fetchStudy(id: Study.ID) async throws -> StudyDetail {
        guard isDetailAPIEnabled else { throw RepositoryError.unavailable }
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
        guard isListAPIEnabled else { throw RepositoryError.featureUnavailable }
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

    func fetchMyStudies() async throws -> [MyStudy] {
        try Task.checkCancellation()
        guard isMyStudiesAPIEnabled else { throw RepositoryError.featureUnavailable }
        guard let authorization else { throw RepositoryError.unauthorized }
        do {
            let response = try await authorization.withAuthorization { token in
                do {
                    return try await self.client.fetchMyStudies(accessToken: token)
                } catch RepositoryError.unauthorized {
                    // Reuse the auth actor's one-refresh and invalidation policy for HTTP 401.
                    throw AuthRemoteError.unauthorized
                } catch {
                    throw self.mapError(error)
                }
            }
            try Task.checkCancellation()
            return try response.toDomain()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as AuthError {
            switch error {
            case .featureUnavailable: throw RepositoryError.featureUnavailable
            case .authenticationInvalid: throw RepositoryError.unauthorized
            default: throw RepositoryError.unavailable
            }
        } catch {
            throw mapError(error)
        }
    }
}

extension Repository {
    func mapError(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let afError = error as? AFError {
            if afError.isExplicitlyCancelledError { return CancellationError() }
            if case let .sessionTaskFailed(underlying) = afError,
               let urlError = underlying as? URLError,
               urlError.code == .cancelled {
                return CancellationError()
            }
        }
        if let urlError = error as? URLError, urlError.code == .cancelled { return CancellationError() }
        if let repositoryError = error as? RepositoryError { return repositoryError }
        if let afError = error as? AFError {
            if afError.responseCode == 401 { return RepositoryError.unauthorized }
            if afError.responseCode == 403 { return RepositoryError.onboardingRequired }
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

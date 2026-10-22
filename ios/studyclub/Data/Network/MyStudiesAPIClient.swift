import Alamofire
import Foundation

final class MyStudiesAPIClient: Sendable {
    func fetchMyStudies(accessToken: String) async throws -> MyStudyListResponseDTO {
        try Task.checkCancellation()
        let trimmed = accessToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw MyStudiesError.unauthorized
        }

        do {
            return try await AF.request(MyStudiesRouter.myStudies(accessToken: trimmed))
                .validate()
                .serializingDecodable(MyStudyListResponseDTO.self)
                .value
        } catch {
            throw mapError(error)
        }
    }

    func mapError(_ error: any Error) -> any Error {
        if error is CancellationError { return error }
        if let afError = error as? AFError {
            if afError.isExplicitlyCancelledError {
                return CancellationError()
            }
            if case let .sessionTaskFailed(underlying) = afError,
               let urlError = underlying as? URLError,
               urlError.code == .cancelled {
                return CancellationError()
            }
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return CancellationError()
        }
        if let myStudiesError = error as? MyStudiesError { return myStudiesError }
        if let afError = error as? AFError {
            if let statusCode = afError.responseCode {
                switch statusCode {
                case 401: return MyStudiesError.unauthorized
                case 403: return MyStudiesError.onboardingRequired
                default: break
                }
            }
            if afError.underlyingError is DecodingError { return MyStudiesError.invalidData }
        }
        if error is DecodingError { return MyStudiesError.invalidData }
        return MyStudiesError.unavailable
    }
}

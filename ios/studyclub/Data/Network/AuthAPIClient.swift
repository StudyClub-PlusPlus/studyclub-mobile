import Alamofire
import Foundation

final class AuthAPIClient: AuthRemoteAPI {
    func socialLogin(_ authorization: SocialAuthorization) async throws -> AuthSessionDTO {
        try await send(AuthRouter.socialLogin(authorization), as: AuthSessionDTO.self)
    }

    func refresh(refreshToken: String) async throws -> String {
        try await send(AuthRouter.refresh(refreshToken: refreshToken), as: AccessTokenDTO.self).accessToken
    }

    func fetchAccount(accessToken: String) async throws -> AccountDTO {
        try await send(AuthRouter.me(accessToken: accessToken), as: AccountDTO.self)
    }

    func completeOnboarding(accessToken: String, registration: MemberRegistration) async throws -> AccountDTO {
        try await send(
            AuthRouter.onboarding(accessToken: accessToken, body: OnboardingRequestDTO(registration)),
            as: AccountDTO.self
        )
    }

    private func send<T: Decodable & Sendable>(_ router: AuthRouter, as type: T.Type) async throws -> T {
        do {
            return try await AF.request(router).validate().serializingDecodable(type).value
        } catch {
            throw Self.classify(error)
        }
    }

    /// Cancellation stays cancellation. Everything else becomes an `AuthRemoteError`.
    static func classify(_ error: Error) -> Error {
        if error is CancellationError { return error }
        if let afError = error as? AFError {
            if afError.isExplicitlyCancelledError { return CancellationError() }
            if let status = afError.responseCode { return classify(status: status) }
            if let urlError = afError.underlyingError as? URLError { return classify(urlError) }
            return AuthRemoteError.server
        }
        if let urlError = error as? URLError { return classify(urlError) }
        return AuthRemoteError.server
    }

    static func classify(status: Int) -> AuthRemoteError {
        switch status {
        case 401: .unauthorized
        case 400, 422: .badRequest
        case 409: .conflict
        default: .server
        }
    }

    private static func classify(_ error: URLError) -> Error {
        error.code == .cancelled ? CancellationError() : AuthRemoteError.connection
    }
}

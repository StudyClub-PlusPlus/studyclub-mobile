import Foundation

/// Owns member-list transport; credential/refresh policy stays in the shared auth actor.
final class DefaultMyStudiesRepository: MyStudiesRepository {
    private let authorization: DefaultAuthRepository
    private let client = MyStudiesAPIClient()
    private let isFeatureEnabled: Bool

    init(authorization: DefaultAuthRepository, isFeatureEnabled: Bool) {
        self.authorization = authorization
        self.isFeatureEnabled = isFeatureEnabled
    }

    func fetchMyStudies() async throws -> [MyStudy] {
        try Task.checkCancellation()
        guard isFeatureEnabled else { throw MyStudiesError.featureUnavailable }
        do {
            let client = client
            let response = try await authorization.withAuthorization { token in
                do {
                    return try await client.fetchMyStudies(accessToken: token)
                } catch MyStudiesError.unauthorized {
                    // A rejected access token uses the existing one-refresh policy.
                    throw AuthRemoteError.unauthorized
                }
            }
            try Task.checkCancellation()
            return try response.toDomain()
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as MyStudiesError {
            throw error
        } catch let error as AuthError {
            switch error {
            case .featureUnavailable: throw MyStudiesError.featureUnavailable
            case .authenticationInvalid: throw MyStudiesError.unauthorized
            default: throw MyStudiesError.unavailable
            }
        } catch {
            throw MyStudiesError.unavailable
        }
    }
}

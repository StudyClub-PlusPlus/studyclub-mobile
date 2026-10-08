import Alamofire
import Foundation

@MainActor
final class LiveAccountRepository: AccountRepository {
    private let client = AccountAPIClient()
    private let isEnabled: Bool
    private var accessToken: String?
    private var refreshToken: String?

    var hasSession: Bool {
        accessToken?.isEmpty == false
    }

    let supportsDemo = false

    convenience init(accessToken: String?, refreshToken: String? = nil) {
        self.init(
            accessToken: accessToken,
            refreshToken: refreshToken,
            isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.myPage.definition)
        )
    }

    init(accessToken: String?, refreshToken: String? = nil, isEnabled: Bool) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.isEnabled = isEnabled
    }

    func fetchAccount() async throws -> Account {
        try Task.checkCancellation()
        guard isEnabled else {
            throw AccountError.unavailable
        }
        guard let accessToken, !accessToken.isEmpty else {
            throw AccountError.unauthorized
        }

        do {
            let response = try await client.fetchAccount(accessToken: accessToken)
            try Task.checkCancellation()
            return try response.toDomain()
        } catch {
            try Task.checkCancellation()
            let mappedError = mapError(error)
            if mappedError as? AccountError == .unauthorized {
                clearSession()
            }
            throw mappedError
        }
    }

    func startDemoSession() {}

    func clearSession() {
        accessToken = nil
        refreshToken = nil
    }
}

extension LiveAccountRepository {
    func mapError(_ error: any Error) -> any Error {
        if error is CancellationError {
            return error
        }
        if let transportError = error as? AFError, transportError.isExplicitlyCancelledError {
            return CancellationError()
        }
        if let accountError = error as? AccountError {
            return accountError
        }
        if let transportError = error as? AFError {
            if transportError.responseCode == 401 {
                return AccountError.unauthorized
            }
            if transportError.underlyingError is DecodingError {
                return AccountError.invalidData
            }
        }
        if error is DecodingError {
            return AccountError.invalidData
        }
        return AccountError.unavailable
    }
}

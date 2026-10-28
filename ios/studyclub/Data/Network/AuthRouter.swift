import Alamofire
import Foundation

enum AuthRouter: URLRequestConvertible {
    case socialLogin(SocialAuthorization)
    case refresh(refreshToken: String)
    case me(accessToken: String)
    case onboarding(accessToken: String, body: OnboardingRequestDTO)

    private var method: HTTPMethod {
        switch self {
        case .me: .get
        case .socialLogin, .refresh, .onboarding: .post
        }
    }

    /// Auth routes are on the host root. `/api/auth/*` is rejected by the server security filter.
    private static var rootURL: URL { APIHost.root }

    private var url: URL {
        switch self {
        case .socialLogin:
            Self.rootURL.appending(path: "auth").appending(path: "social-login")
        case .refresh:
            Self.rootURL.appending(path: "auth").appending(path: "refresh")
        case .me:
            Self.rootURL.appending(path: "auth").appending(path: "me")
        case .onboarding:
            Self.rootURL.appending(path: "accounts").appending(path: "onboarding")
        }
    }

    func asURLRequest() throws -> URLRequest {
        var request = URLRequest(url: url)
        request.method = method
        request.headers = [.accept("application/json")]
        switch self {
        case let .socialLogin(authorization):
            // Google: the SDK's serverAuthCode is issued without a callback, so redirectUri is an
            // explicit empty string (omitting it makes the server use its web callback).
            // Apple: the first-time name rides along; Apple never sends it again.
            let isGoogle = authorization.provider == .google
            return try JSONParameterEncoder.default.encode(
                SocialLoginBody(
                    code: authorization.code,
                    provider: authorization.provider.rawValue,
                    platform: "CORE",
                    redirectUri: isGoogle ? "" : nil,
                    name: isGoogle ? nil : authorization.name
                ),
                into: request
            )
        case let .refresh(refreshToken):
            return try JSONParameterEncoder.default.encode(RefreshBody(refreshToken: refreshToken), into: request)
        case let .me(accessToken):
            request.headers.add(.authorization(bearerToken: accessToken))
            return request
        case let .onboarding(accessToken, body):
            request.headers.add(.authorization(bearerToken: accessToken))
            return try JSONParameterEncoder.default.encode(body, into: request)
        }
    }

    private struct SocialLoginBody: Encodable {
        let code: String
        let provider: String
        let platform: String
        let redirectUri: String?
        let name: String?
    }

    private struct RefreshBody: Encodable { let refreshToken: String }
}

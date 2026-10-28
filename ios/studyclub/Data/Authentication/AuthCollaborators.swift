import Foundation

/// Tokens issued by the server. Stored only for a completed member.
struct AuthTokens: Equatable, Codable, Sendable {
    var accessToken: String
    var refreshToken: String

    func validate() throws {
        guard !accessToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !refreshToken.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AuthRemoteError.server
        }
    }
}

/// Server-classified failure of an authentication request. Data-internal.
enum AuthRemoteError: Error, Equatable, Sendable {
    /// HTTP 401: the token or authorization was rejected before the request took effect.
    case unauthorized
    /// HTTP 400/422: the server refused the input.
    case badRequest
    /// HTTP 409: the request conflicts with existing data (for example a nickname in use).
    case conflict
    /// Transport failure. The server may or may not have processed the request.
    case connection
    /// Other status, undecodable response or server fault.
    case server
}

/// One-time provider authorization handed to `/auth/social-login`.
struct SocialAuthorization: Equatable, Sendable {
    enum Provider: String, Sendable {
        case google, apple
    }

    let provider: Provider
    let code: String
    /// Apple only: the name Apple returns on the first authorization. Never stored.
    var name: String?
}

/// Server endpoints used by session orchestration. The concrete `AuthAPIClient` owns transport.
protocol AuthRemoteAPI: Sendable {
    func socialLogin(_ authorization: SocialAuthorization) async throws -> AuthSessionDTO
    /// Returns the new access token.
    func refresh(refreshToken: String) async throws -> String
    func fetchAccount(accessToken: String) async throws -> AccountDTO
    func completeOnboarding(accessToken: String, registration: MemberRegistration) async throws -> AccountDTO
}

/// Runs Google authentication and returns the one-time authorization for the server.
/// Throws `AuthError.configurationMissing`, `.userCancelled`, `.unavailable` or `CancellationError`.
protocol GoogleAuthorizationProviding: Sendable {
    func authorizationCode() async throws -> String
}

/// Runs Sign in with Apple and returns the authorization code plus the first-time name.
/// Throws `AuthError.userCancelled`, `.unavailable` or `CancellationError`.
protocol AppleAuthorizationProviding: Sendable {
    func authorization() async throws -> SocialAuthorization
}

enum CredentialStoreError: Error, Equatable, Sendable {
    /// Stored data cannot be decoded.
    case corrupted
    case failure(status: Int32)
}

/// Identifies one staged write. Pending credentials never represent a restorable session.
struct PendingCredentialWrite: Equatable, Sendable, Codable {
    let id: UUID
}

protocol CredentialStore: Sendable {
    /// Reads only the last committed credentials, ignoring every pending write.
    func load() throws -> AuthTokens?
    /// Stages credentials without changing the committed session.
    @discardableResult func save(_ tokens: AuthTokens) throws -> PendingCredentialWrite
    /// Atomically replaces the committed session, or throws and preserves it.
    /// The Repository can still compensate this write before publishing a current result.
    func commit(_ write: PendingCredentialWrite) throws
    /// Conditionally restores the previous session only if this write is still active.
    /// Failure leaves invalidation incomplete and must reach the feature owner.
    func rollback(_ write: PendingCredentialWrite) throws
    /// Removes only this pending write. Failure cannot expose it through load().
    func discard(_ write: PendingCredentialWrite) throws
    /// Deletes the committed session; succeeds when nothing is stored.
    func delete() throws
}

/// Per-repository invalidation clock. A request can advance it while the actor is in a
/// synchronous credential write; only this counter crosses that boundary, never session state.
class AuthInvalidationClock: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    var current: Int { lock.lock(); defer { lock.unlock() }; return value }

    /// Orders final publication against an invalidation request with no gap between checking
    /// the epoch and completing the actor-owned write. The closure must not reenter this clock.
    func complete(_ epoch: Int, _ publish: () throws -> Void) throws {
        lock.lock()
        defer { lock.unlock() }
        guard value == epoch else { throw CancellationError() }
        try publish()
    }

    func advance() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}

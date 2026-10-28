import Foundation

/// Owns Google authentication, the completed-member session and its credentials.
///
/// `epoch` is an invalidation counter, not a request generation counter for Presentation.
/// Requests recheck epoch, cancellation and the flag after suspension and synchronous writes.
/// Each credential write has an identity and preserves its previous completed session. A late
/// cancellation/OFF compensates only that write. Explicit invalidation waits on this actor and
/// reports compensation failure rather than claiming the feature has finished cancelling.
actor DefaultAuthRepository: AuthRepository {
    private enum Phase {
        case editing, submitting, uncertain, checking
    }

    /// In-memory only. Process termination, discard and logout clear it.
    private struct PendingSignup {
        var tokens: AuthTokens
        let accountID: Int64
        let suggestedNickname: String?
        var phase: Phase
    }

    private let api: any AuthRemoteAPI
    private let google: any GoogleAuthorizationProviding
    private let apple: any AppleAuthorizationProviding
    private let store: any CredentialStore
    private let isFeatureEnabled: @Sendable () -> Bool
    private nonisolated let invalidation: AuthInvalidationClock
    private var epoch: Int { invalidation.current }
    private var pending: PendingSignup?
    private var credentialRecovery: (write: PendingCredentialWrite, epoch: Int)?

    init() {
        self.init(
            api: AuthAPIClient(),
            google: GoogleSignInProvider(),
            apple: AppleSignInProvider(),
            store: KeychainCredentialStore(),
            isFeatureEnabled: { DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition) }
        )
    }

    init(
        api: any AuthRemoteAPI,
        google: any GoogleAuthorizationProviding,
        apple: any AppleAuthorizationProviding = AppleSignInProvider(),
        store: any CredentialStore,
        isFeatureEnabled: @escaping @Sendable () -> Bool
    ) {
        self.init(api: api, google: google, apple: apple, store: store,
                  isFeatureEnabled: isFeatureEnabled, invalidation: AuthInvalidationClock())
    }

    init(
        api: any AuthRemoteAPI,
        google: any GoogleAuthorizationProviding,
        apple: any AppleAuthorizationProviding = AppleSignInProvider(),
        store: any CredentialStore,
        isFeatureEnabled: @escaping @Sendable () -> Bool,
        invalidation: AuthInvalidationClock
    ) {
        self.api = api
        self.google = google
        self.apple = apple
        self.store = store
        self.isFeatureEnabled = isFeatureEnabled
        self.invalidation = invalidation
    }

    // MARK: - AuthRepository

    /// Data-only authorization seam for member repositories. Tokens never enter Domain or UI.
    /// Shares the same invalidation clock, refresh and transactional storage as authentication.
    func withAuthorization<Value: Sendable>(
        _ request: @Sendable (String) async throws -> Value
    ) async throws -> Value {
        let epoch = try begin()
        let tokens: AuthTokens
        do {
            guard let stored = try store.load() else { throw AuthError.authenticationInvalid }
            tokens = stored
            try tokens.validate()
        } catch let error as AuthError {
            throw error
        } catch {
            throw AuthError.unavailable
        }
        do {
            let result = try await authorized(tokens, epoch: epoch, request)
            try ensureCurrent(epoch)
            if result.tokens != tokens { try saveCredentials(result.tokens, epoch: epoch) }
            return result.value
        } catch AuthRemoteError.unauthorized {
            try ensureCurrent(epoch)
            try deleteStoredSession()
            throw AuthError.authenticationInvalid
        } catch AuthRemoteError.connection {
            throw AuthError.connectionFailure
        }
    }

    func restoreSession() async throws -> Member? {
        let epoch = try begin()
        let stored: AuthTokens
        do {
            guard let tokens = try store.load() else { return nil }
            stored = tokens
        } catch CredentialStoreError.corrupted {
            // Unreadable data cannot represent a completed member. A failed delete is not anonymity.
            try deleteStoredSession()
            return nil
        } catch {
            throw AuthError.unavailable
        }

        do {
            try stored.validate()
            let result = try await authorized(stored, epoch: epoch) {
                try await self.api.fetchAccount(accessToken: $0)
            }
            guard let member = try result.value.toMember() else {
                // The server says this account never completed signup, so nothing may persist.
                try deleteStoredSession()
                return nil
            }
            if result.tokens != stored {
                try saveCredentials(result.tokens, epoch: epoch)
            }
            return member
        } catch let error as AuthRemoteError {
            switch error {
            case .unauthorized:
                // Confirmed invalid: become anonymous without opening any screen.
                // If deletion fails, the credentials are still stored, so this is not anonymity.
                try deleteStoredSession()
                return nil
            case .connection:
                throw AuthError.connectionFailure
            case .badRequest, .conflict, .server:
                throw AuthError.unavailable
            }
        }
    }

    func signInWithGoogle() async throws -> SignInOutcome {
        try await signIn { [google] in
            SocialAuthorization(provider: .google, code: try await google.authorizationCode())
        }
    }

    func signInWithApple() async throws -> SignInOutcome {
        try await signIn { [apple] in try await apple.authorization() }
    }

    /// Provider authorization, then the shared server exchange and session publication.
    private func signIn(
        _ authorize: @escaping @Sendable () async throws -> SocialAuthorization
    ) async throws -> SignInOutcome {
        _ = try begin()
        let epoch = invalidate()
        let authorization = try await guarded(epoch) { try await authorize() }
        do {
            let session = try await guarded(epoch) { try await api.socialLogin(authorization) }
            let tokens = try session.validatedTokens()
            if let member = try session.account.toMember() {
                try commit(tokens, epoch: epoch)
                return .member(member)
            }
            let suggested = Self.normalized(session.suggestedNickname)
            pending = PendingSignup(tokens: tokens, accountID: session.account.id, suggestedNickname: suggested, phase: .editing)
            return .signupRequired(suggestedNickname: suggested)
        } catch let error as AuthRemoteError {
            switch error {
            case .unauthorized, .badRequest, .conflict: throw AuthError.authenticationInvalid
            case .connection: throw AuthError.connectionFailure
            case .server: throw AuthError.unavailable
            }
        }
    }

    func completeSignup(_ registration: MemberRegistration) async throws -> Member {
        let epoch = try begin()
        guard registration.hasRequiredConsents else { throw AuthError.signupRejected(.consentRequired) }
        guard registration.hasNickname else { throw AuthError.signupRejected(.invalidInput) }
        guard let signup = pending, signup.phase == .editing else { throw AuthError.noPendingSignup }

        pending?.phase = .submitting
        do {
            let result = try await authorized(signup.tokens, epoch: epoch) {
                try await self.api.completeOnboarding(accessToken: $0, registration: registration)
            }
            guard let member = try result.value.toMember(expectedID: signup.accountID) else {
                // A success response that is not complete is not trusted: confirm instead.
                pending?.phase = .uncertain
                throw AuthError.signupStatusUnknown
            }
            try commit(result.tokens, epoch: epoch)
            return member
        } catch let error as AuthRemoteError {
            switch error {
            case .badRequest:
                pending?.phase = .editing
                throw AuthError.signupRejected(.invalidInput)
            case .conflict:
                pending?.phase = .editing
                throw AuthError.signupRejected(.nicknameTaken)
            case .unauthorized:
                pending = nil
                throw AuthError.authenticationInvalid
            case .connection, .server:
                // The server may have completed the signup. Never submit again blindly.
                pending?.phase = .uncertain
                throw AuthError.signupStatusUnknown
            }
        } catch is CancellationError {
            // A cancelled submission may still have reached the server.
            if epoch == self.epoch, pending != nil { pending?.phase = .uncertain }
            throw CancellationError()
        }
    }

    func checkSignupCompletion() async throws -> SignInOutcome {
        let epoch = try begin()
        guard let signup = pending, signup.phase == .uncertain else { throw AuthError.noPendingSignup }

        pending?.phase = .checking
        do {
            let result = try await authorized(signup.tokens, epoch: epoch) {
                try await self.api.fetchAccount(accessToken: $0)
            }
            if let member = try result.value.toMember(expectedID: signup.accountID) {
                try commit(result.tokens, epoch: epoch)
                return .member(member)
            }
            pending?.tokens = result.tokens
            pending?.phase = .editing
            return .signupRequired(suggestedNickname: signup.suggestedNickname)
        } catch let error as AuthRemoteError {
            if error == .unauthorized {
                pending = nil
                throw AuthError.authenticationInvalid
            }
            pending?.phase = .uncertain
            throw error == .connection ? AuthError.connectionFailure : AuthError.unavailable
        } catch is CancellationError {
            if epoch == self.epoch, pending != nil { pending?.phase = .uncertain }
            throw CancellationError()
        }
    }

    nonisolated func discardPendingSignup() async throws {
        // Signal before waiting for the actor: OFF -> ON or a close during a slow commit
        // must invalidate that commit even when the actor cannot yet process the request.
        let epoch = invalidation.advance()
        try await finishInvalidation(epoch)
    }

    private func finishInvalidation(_ epoch: Int) throws {
        if epoch == self.epoch { pending = nil }
        if let recovery = credentialRecovery, recovery.epoch < epoch { try recoverCredentials() }
    }

    func logout() async throws {
        _ = try begin()
        // No suspension point from here on: invalidation and deletion happen together.
        invalidate()
        do {
            try store.delete()
        } catch {
            throw AuthError.logoutFailed
        }
    }

    // MARK: - Guards

    private func begin() throws -> Int {
        try Task.checkCancellation()
        guard isFeatureEnabled() else {
            invalidate()
            throw AuthError.featureUnavailable
        }
        try recoverCredentials()
        return epoch
    }

    @discardableResult
    private func invalidate() -> Int {
        let epoch = invalidation.advance()
        pending = nil
        return epoch
    }

    private func ensureCurrent(_ epoch: Int) throws {
        try Task.checkCancellation()
        guard epoch == self.epoch else { throw CancellationError() }
        guard isFeatureEnabled() else {
            invalidate()
            throw AuthError.featureUnavailable
        }
    }

    /// Runs suspended work. A stale epoch or a disabled flag replaces the suspended result.
    /// Check before starting as well as after finishing; a slow synchronous load may have
    /// been cancelled or disabled before the next network request.
    private func guarded<T>(_ epoch: Int, _ work: () async throws -> T) async throws -> T {
        try ensureCurrent(epoch)
        let value: T
        do {
            value = try await work()
        } catch {
            try ensureCurrent(epoch)
            throw error
        }
        try ensureCurrent(epoch)
        return value
    }

    /// Calls the server with the access token. A 401 means the request had no effect, so it
    /// refreshes the access token once and repeats the call.
    private func authorized<T>(
        _ tokens: AuthTokens,
        epoch: Int,
        _ request: (String) async throws -> T
    ) async throws -> (value: T, tokens: AuthTokens) {
        do {
            let value = try await guarded(epoch) { try await request(tokens.accessToken) }
            return (value, tokens)
        } catch AuthRemoteError.unauthorized {
            let accessToken = try await guarded(epoch) {
                try await api.refresh(refreshToken: tokens.refreshToken)
            }
            let refreshed = AuthTokens(accessToken: accessToken, refreshToken: tokens.refreshToken)
            try refreshed.validate()
            let value = try await guarded(epoch) { try await request(accessToken) }
            return (value, refreshed)
        }
    }

    /// Stores credentials for a confirmed complete member and ends the pending signup.
    private func commit(_ tokens: AuthTokens, epoch: Int) throws {
        do {
            try saveCredentials(tokens, epoch: epoch)
        } catch AuthError.unavailable {
            if pending != nil {
                pending?.tokens = tokens
                pending?.phase = .uncertain
                throw AuthError.signupStatusUnknown
            }
            throw AuthError.unavailable
        }
        pending = nil
    }

    private func saveCredentials(_ tokens: AuthTokens, epoch: Int) throws {
        try ensureCurrent(epoch)
        let write: PendingCredentialWrite
        do { write = try store.save(tokens) }
        catch { throw AuthError.unavailable }
        credentialRecovery = (write, epoch)
        do {
            try ensureCurrent(epoch)
            do { try store.commit(write) }
            catch { throw AuthError.unavailable }
            try ensureCurrent(epoch)
            // Cleanup is not the commit: a failed cleanup does not revoke a valid session.
            try? store.discard(write)
            try invalidation.complete(epoch) {
                try Task.checkCancellation()
                guard isFeatureEnabled() else { throw AuthError.featureUnavailable }
                credentialRecovery = nil
            }
        } catch {
            if error as? AuthError == .featureUnavailable { invalidate() }
            // This is explicit cancellation cleanup even if the feature has just become OFF.
            // On failure keep the write identity so awaited invalidation can retry it.
            try recoverCredentials()
            throw error
        }
    }

    private func recoverCredentials() throws {
        guard let recovery = credentialRecovery else { return }
        do { try store.rollback(recovery.write) }
        catch { throw AuthError.unavailable }
        credentialRecovery = nil
    }

    /// Deletes completed-member credentials. Failure stays a failure and leaves them in place.
    private func deleteStoredSession() throws {
        // Rejection supersedes all concurrent consumers before synchronous storage work.
        // A failed deletion still throws; it never becomes successful anonymous state.
        invalidate()
        do {
            try store.delete()
        } catch {
            throw AuthError.unavailable
        }
    }

    private static func normalized(_ nickname: String?) -> String? {
        guard let trimmed = nickname?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else { return nil }
        return trimmed
    }
}

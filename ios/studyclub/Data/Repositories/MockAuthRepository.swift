#if DEBUG
import Foundation

/// Debug-only trusted session samples for screen QA. Nothing is persisted and no network or Google
/// SDK is used, so it proves no live login behavior. A new sign-in always needs signup.
actor MockAuthRepository: AuthRepository {
    private let isFeatureEnabled: @Sendable () -> Bool
    private var member: Member?
    private var isSigningUp = false

    init(isFeatureEnabled: @escaping @Sendable () -> Bool) {
        self.isFeatureEnabled = isFeatureEnabled
    }

    func restoreSession() async throws -> Member? {
        try requireEnabled()
        return member
    }

    func signInWithGoogle() async throws -> SignInOutcome {
        try requireEnabled()
        isSigningUp = true
        return .signupRequired(suggestedNickname: "스터디친구")
    }

    func completeSignup(_ registration: MemberRegistration) async throws -> Member {
        try requireEnabled()
        guard registration.hasRequiredConsents else { throw AuthError.signupRejected(.consentRequired) }
        guard registration.hasNickname else { throw AuthError.signupRejected(.invalidInput) }
        guard isSigningUp else { throw AuthError.noPendingSignup }
        let completed = Member(nickname: registration.nickname.trimmingCharacters(in: .whitespacesAndNewlines))
        member = completed
        isSigningUp = false
        return completed
    }

    func checkSignupCompletion() async throws -> SignInOutcome {
        try requireEnabled()
        throw AuthError.noPendingSignup
    }

    func discardPendingSignup() async throws {
        isSigningUp = false
    }

    func logout() async throws {
        try requireEnabled()
        member = nil
        isSigningUp = false
    }

    private func requireEnabled() throws {
        guard isFeatureEnabled() else {
            isSigningUp = false
            throw AuthError.featureUnavailable
        }
    }
}
#endif

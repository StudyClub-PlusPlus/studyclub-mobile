import Foundation

/// A member whose signup the server has confirmed as complete.
/// Tokens and other personal data stay inside Data.
struct Member: Equatable, Sendable {
    let nickname: String
}

/// Input for finishing signup. Required consents have no default value.
struct MemberRegistration: Equatable, Sendable {
    let nickname: String
    let timeZone: String
    let age14Confirmed: Bool
    let termsOfServiceAgreed: Bool
    let privacyPolicyAgreed: Bool
    let marketingAgreed: Bool

    var hasNickname: Bool {
        !nickname.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasRequiredConsents: Bool {
        age14Confirmed && termsOfServiceAgreed && privacyPolicyAgreed
    }
}

/// Result of Google authentication or a signup completion check.
enum SignInOutcome: Equatable, Sendable {
    /// Existing or just-confirmed member. Credentials are stored.
    case member(Member)
    /// Signup is incomplete. Temporary authentication is held in memory only.
    case signupRequired(suggestedNickname: String?)
}

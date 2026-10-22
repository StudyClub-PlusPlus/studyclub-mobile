import Foundation

/// Google authentication, completed-member session storage, restoration and logout.
///
/// Every operation checks the `auth.google-login` flag and suppresses invalidated results.
/// The feature owner cancels its task, then awaits `discardPendingSignup()` before completing
/// cancellation, closing or replacing the feature. An invalidation failure stays a retryable
/// failure; it must not be shown as anonymous or completed cancellation. OFF keeps previously
/// completed credentials and starts no new authentication.
protocol AuthRepository: Sendable {
    /// Verifies stored credentials with the server. Returns nil for anonymous: nothing stored, or
    /// the server confirmed the credentials invalid (they are then deleted). Transient failures
    /// throw `connectionFailure` or `unavailable` and keep the stored credentials.
    func restoreSession() async throws -> Member?

    /// Runs Google authentication and exchanges it with the server. A complete member is stored.
    /// Incomplete signup keeps temporary authentication in memory only.
    func signInWithGoogle() async throws -> SignInOutcome

    /// Submits signup once. Stores credentials only after the server confirms completion.
    /// An uncertain result throws `signupStatusUnknown`; call `checkSignupCompletion()` instead of
    /// submitting again.
    func completeSignup(_ registration: MemberRegistration) async throws -> Member

    /// Rechecks completion after `signupStatusUnknown`. A confirmed complete signup is stored.
    /// A confirmed incomplete signup returns to editing. Failures keep the unknown state.
    func checkSignupCompletion() async throws -> SignInOutcome

    /// Abandons signup and waits for invalidation of in-flight credential writes.
    /// Throws unavailable if storage compensation cannot complete; do not show cancellation
    /// as complete until this call succeeds. Previously completed credentials are preserved.
    func discardPendingSignup() async throws

    /// Deletes stored credentials and ends the session. Throws `logoutFailed` and keeps the
    /// session when the credentials cannot be deleted.
    func logout() async throws
}

enum AuthError: Error, Equatable, Sendable {
    /// The `auth.google-login` flag is OFF. Stored credentials are kept.
    case featureUnavailable
    /// Verified Google or server configuration is absent. Authentication never starts.
    case configurationMissing
    /// The user dismissed Google authentication.
    case userCancelled
    /// Transient network failure. Stored credentials are kept; retry the check.
    case connectionFailure
    /// The server rejected the credentials, temporary authentication or Google authorization.
    case authenticationInvalid
    /// The server definitely refused the signup input. The user may edit and submit again.
    case signupRejected(SignupRejection)
    /// The signup outcome is uncertain. Check completion; do not submit again.
    case signupStatusUnknown
    /// No signup is waiting, or the call does not match its current phase.
    case noPendingSignup
    /// Credentials could not be deleted. The session is unchanged.
    case logoutFailed
    /// Server, response or storage failure that does not fit the cases above.
    case unavailable
}

enum SignupRejection: Equatable, Sendable {
    case nicknameTaken
    case invalidInput
    case consentRequired
}

import XCTest
@testable import studyclub

final class DefaultAuthRepositoryTests: XCTestCase {
    private struct Harness {
        let api = FakeAuthAPI()
        let google = FakeGoogle()
        let store: FakeCredentialStore
        let flag = Locked(true)
        let repository: DefaultAuthRepository

        init(stored: AuthTokens? = nil) {
            let api = api, google = google, flag = flag
            let store = FakeCredentialStore(tokens: stored)
            self.store = store
            repository = DefaultAuthRepository(
                api: api, google: google, store: store, isFeatureEnabled: { flag.read { $0 } }
            )
        }
    }

    private func expect<T>(
        _ expected: AuthError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> T
    ) async {
        do {
            _ = try await body()
            XCTFail("Expected \(expected)", file: file, line: line)
        } catch {
            XCTAssertEqual(error as? AuthError, expected, file: file, line: line)
        }
    }

    private func expectCancellation<T>(
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> T
    ) async {
        do {
            _ = try await body()
            XCTFail("Expected cancellation", file: file, line: line)
        } catch {
            XCTAssertTrue(error is CancellationError, "Unexpected \(error)", file: file, line: line)
        }
    }

    private func signedInAwaitingSignup(_ harness: Harness) async throws {
        harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.incompleteAccount) }
        _ = try await harness.repository.signInWithGoogle()
    }

    // MARK: - Sign in

    func testExistingMemberIsStoredAndReturned() async throws {
        let harness = Harness()
        harness.api.onSocialLogin = { code in
            XCTAssertEqual(code, "google-code")
            return AuthFixtures.session(account: AuthFixtures.completedAccount)
        }

        let outcome = try await harness.repository.signInWithGoogle()

        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.sessionTokens)
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
    }

    func testIncompleteSignupKeepsCredentialsInMemoryOnly() async throws {
        let harness = Harness()
        harness.api.onSocialLogin = { _ in
            AuthFixtures.session(account: AuthFixtures.incompleteAccount, suggested: "  구글 이름 ")
        }

        let outcome = try await harness.repository.signInWithGoogle()

        XCTAssertEqual(outcome, .signupRequired(suggestedNickname: "구글 이름"))
        XCTAssertNil(harness.store.tokens)
        XCTAssertEqual(harness.store.saveCount, 0)
    }

    func testBlankSuggestedNicknameBecomesNil() async throws {
        let harness = Harness()
        harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.incompleteAccount, suggested: " ") }
        let outcome = try await harness.repository.signInWithGoogle()
        XCTAssertEqual(outcome, .signupRequired(suggestedNickname: nil))
    }

    func testMissingConfigurationStopsBeforeAnyRequest() async {
        let harness = Harness()
        harness.google.onAuthorize = { throw AuthError.configurationMissing }
        await expect(.configurationMissing) { try await harness.repository.signInWithGoogle() }
        XCTAssertEqual(harness.api.recordedCalls, [])
        XCTAssertNil(harness.store.tokens)
    }

    func testUserCancellationFromGooglePassesThrough() async {
        let harness = Harness()
        harness.google.onAuthorize = { throw AuthError.userCancelled }
        await expect(.userCancelled) { try await harness.repository.signInWithGoogle() }
        XCTAssertEqual(harness.api.recordedCalls, [])
    }

    func testSignInFailuresAreClassified() async {
        let cases: [(AuthRemoteError, AuthError)] = [
            (.unauthorized, .authenticationInvalid), (.badRequest, .authenticationInvalid),
            (.conflict, .authenticationInvalid), (.connection, .connectionFailure), (.server, .unavailable)
        ]
        for (remote, expected) in cases {
            let harness = Harness()
            harness.api.onSocialLogin = { _ in throw remote }
            await expect(expected) { try await harness.repository.signInWithGoogle() }
            XCTAssertNil(harness.store.tokens)
        }
    }

    func testCompletedAccountWithoutNicknameIsNotAMember() async {
        let harness = Harness()
        harness.api.onSocialLogin = { _ in
            AuthFixtures.session(account: AccountDTO(id: 1, nickname: " ", onboardingCompletedAt: "2026-10-01T00:00:00Z"))
        }
        await expect(.unavailable) { try await harness.repository.signInWithGoogle() }
        XCTAssertNil(harness.store.tokens)
    }

    func testCredentialSaveFailureDoesNotReturnAMember() async {
        let harness = Harness()
        harness.store.failSave(with: .failure(status: -1))
        harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
        await expect(.unavailable) { try await harness.repository.signInWithGoogle() }
        XCTAssertNil(harness.store.tokens)
    }

    // MARK: - Signup

    func testSignupCompletionStoresCredentialsOnlyAfterServerConfirms() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let seen = Locked<[(String, MemberRegistration)]>([])
        harness.api.onOnboarding = { token, registration in
            seen.mutate { $0.append((token, registration)) }
            return AuthFixtures.completedAccount
        }
        XCTAssertNil(harness.store.tokens)

        let member = try await harness.repository.completeSignup(AuthFixtures.registration())

        XCTAssertEqual(member, Member(nickname: "수연"))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertEqual(seen.read { $0.map(\.0) }, [AuthFixtures.sessionTokens.accessToken])
    }

    func testMissingRequiredConsentNeverReachesTheServer() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        for registration in [
            AuthFixtures.registration(age: false),
            AuthFixtures.registration(terms: false),
            AuthFixtures.registration(privacy: false)
        ] {
            await expect(.signupRejected(.consentRequired)) { try await harness.repository.completeSignup(registration) }
        }
        await expect(.signupRejected(.invalidInput)) {
            try await harness.repository.completeSignup(AuthFixtures.registration(nickname: "  "))
        }
        XCTAssertEqual(harness.api.count(of: "onboarding"), 0)
    }

    func testDefiniteRejectionsAllowEditingAndResubmission() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let failure = Locked<AuthRemoteError?>(.conflict)
        harness.api.onOnboarding = { _, _ in
            if let error = failure.read({ $0 }) { throw error }
            return AuthFixtures.completedAccount
        }

        await expect(.signupRejected(.nicknameTaken)) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        failure.mutate { $0 = .badRequest }
        await expect(.signupRejected(.invalidInput)) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        failure.mutate { $0 = nil }
        let member = try await harness.repository.completeSignup(AuthFixtures.registration())

        XCTAssertEqual(member.nickname, "수연")
        XCTAssertEqual(harness.api.count(of: "onboarding"), 3)
    }

    func testUncertainSubmissionForcesRecheckInsteadOfResubmission() async throws {
        for uncertain in [AuthRemoteError.connection, .server] {
            let harness = Harness()
            try await signedInAwaitingSignup(harness)
            harness.api.onOnboarding = { _, _ in throw uncertain }

            await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }

            XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
            XCTAssertNil(harness.store.tokens)
        }
    }

    func testSuccessResponseThatIsNotCompleteIsTreatedAsUncertain() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.api.onOnboarding = { _, _ in AuthFixtures.incompleteAccount }
        await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        XCTAssertNil(harness.store.tokens)
    }

    func testRecheckConfirmingCompletionStoresCredentials() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.api.onOnboarding = { _, _ in throw AuthRemoteError.connection }
        await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        harness.api.onFetchAccount = { token in
            XCTAssertEqual(token, AuthFixtures.sessionTokens.accessToken)
            return AuthFixtures.completedAccount
        }

        let outcome = try await harness.repository.checkSignupCompletion()

        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
    }

    func testRecheckConfirmingIncompleteReturnsToEditing() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let shouldFail = Locked(true)
        harness.api.onOnboarding = { _, _ in
            if shouldFail.read({ $0 }) { throw AuthRemoteError.server }
            return AuthFixtures.completedAccount
        }
        await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        harness.api.onFetchAccount = { _ in AuthFixtures.incompleteAccount }

        let outcome = try await harness.repository.checkSignupCompletion()
        XCTAssertEqual(outcome, .signupRequired(suggestedNickname: "구글이름"))
        XCTAssertNil(harness.store.tokens)

        shouldFail.mutate { $0 = false }
        let member = try await harness.repository.completeSignup(AuthFixtures.registration())
        XCTAssertEqual(member.nickname, "수연")
    }

    func testFailedRecheckKeepsUncertainStateAndNeverStoresCredentials() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.api.onOnboarding = { _, _ in throw AuthRemoteError.connection }
        await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }

        harness.api.onFetchAccount = { _ in throw AuthRemoteError.connection }
        await expect(.connectionFailure) { try await harness.repository.checkSignupCompletion() }
        harness.api.onFetchAccount = { _ in throw AuthRemoteError.server }
        await expect(.unavailable) { try await harness.repository.checkSignupCompletion() }
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }

        harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
        let outcome = try await harness.repository.checkSignupCompletion()
        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
    }

    func testRecheckRequiresAnUncertainSubmission() async throws {
        let harness = Harness()
        await expect(.noPendingSignup) { try await harness.repository.checkSignupCompletion() }
        try await signedInAwaitingSignup(harness)
        await expect(.noPendingSignup) { try await harness.repository.checkSignupCompletion() }
        XCTAssertEqual(harness.api.count(of: "fetchAccount"), 0)
    }

    func testExpiredTemporaryAccessTokenIsRefreshedOnceAndSubmissionRetried() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.api.onOnboarding = { token, _ in
            if token == AuthFixtures.sessionTokens.accessToken { throw AuthRemoteError.unauthorized }
            XCTAssertEqual(token, "fresh-access")
            return AuthFixtures.completedAccount
        }
        harness.api.onRefresh = { refresh in
            XCTAssertEqual(refresh, AuthFixtures.sessionTokens.refreshToken)
            return "fresh-access"
        }

        _ = try await harness.repository.completeSignup(AuthFixtures.registration())

        XCTAssertEqual(harness.store.tokens, AuthTokens(accessToken: "fresh-access", refreshToken: "session-refresh"))
    }

    func testRejectedTemporaryAuthenticationEndsSignup() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.api.onOnboarding = { _, _ in throw AuthRemoteError.unauthorized }
        harness.api.onRefresh = { _ in throw AuthRemoteError.unauthorized }

        await expect(.authenticationInvalid) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        XCTAssertNil(harness.store.tokens)
    }

    func testDiscardClearsTemporaryAuthentication() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        try await harness.repository.discardPendingSignup()
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        XCTAssertEqual(harness.api.count(of: "onboarding"), 0)
    }

    func testDiscardKeepsCompletedCredentials() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        try await harness.repository.discardPendingSignup()
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
        XCTAssertEqual(harness.store.saveCount, 0)
    }

    func testSignupSaveFailureStaysUncertainUntilRecheckStoresCredentials() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        harness.store.failSave(with: .failure(status: -1))
        harness.api.onOnboarding = { _, _ in AuthFixtures.completedAccount }

        await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        XCTAssertNil(harness.store.tokens)
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }

        harness.store.failSave(with: nil)
        harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
        let outcome = try await harness.repository.checkSignupCompletion()

        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
    }

    // MARK: - Restore

    func testRestoreWithoutCredentialsIsAnonymousWithoutNetwork() async throws {
        let harness = Harness()
        let member = try await harness.repository.restoreSession()
        XCTAssertNil(member)
        XCTAssertEqual(harness.api.recordedCalls, [])
    }

    func testRestoreVerifiesStoredCredentialsBeforeReturningAMember() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { token in
            XCTAssertEqual(token, AuthFixtures.storedTokens.accessToken)
            return AuthFixtures.completedAccount
        }

        let member = try await harness.repository.restoreSession()

        XCTAssertEqual(member, Member(nickname: "수연"))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
        XCTAssertEqual(harness.api.count(of: "refresh"), 0)
    }

    func testRestoreRefreshesExpiredAccessTokenAndPersistsIt() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { token in
            if token == AuthFixtures.storedTokens.accessToken { throw AuthRemoteError.unauthorized }
            XCTAssertEqual(token, "new-access")
            return AuthFixtures.completedAccount
        }
        harness.api.onRefresh = { refresh in
            XCTAssertEqual(refresh, AuthFixtures.storedTokens.refreshToken)
            return "new-access"
        }

        let member = try await harness.repository.restoreSession()

        XCTAssertEqual(member, Member(nickname: "수연"))
        XCTAssertEqual(harness.store.tokens, AuthTokens(accessToken: "new-access", refreshToken: "stored-refresh"))
    }

    func testConfirmedInvalidDeleteFailureIsNotAnonymity() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        harness.api.onRefresh = { _ in throw AuthRemoteError.unauthorized }
        harness.store.failDelete(with: .failure(status: -1))

        await expect(.unavailable) { try await harness.repository.restoreSession() }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testConfirmedInvalidCredentialsBecomeAnonymousAndAreDeleted() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        harness.api.onRefresh = { _ in throw AuthRemoteError.unauthorized }

        let member = try await harness.repository.restoreSession()

        XCTAssertNil(member)
        XCTAssertNil(harness.store.tokens)
    }

    func testTransientFailuresKeepStoredCredentials() async {
        let cases: [(AuthRemoteError, AuthError)] = [
            (.connection, .connectionFailure), (.server, .unavailable), (.badRequest, .unavailable), (.conflict, .unavailable)
        ]
        for (remote, expected) in cases {
            let harness = Harness(stored: AuthFixtures.storedTokens)
            harness.api.onFetchAccount = { _ in throw remote }
            await expect(expected) { try await harness.repository.restoreSession() }
            XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
        }
    }

    func testTransientRefreshFailureKeepsStoredCredentials() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        harness.api.onRefresh = { _ in throw AuthRemoteError.connection }
        await expect(.connectionFailure) { try await harness.repository.restoreSession() }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testRestoredAccountThatNeverCompletedSignupDoesNotPersist() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in AuthFixtures.incompleteAccount }
        let member = try await harness.repository.restoreSession()
        XCTAssertNil(member)
        XCTAssertNil(harness.store.tokens)
    }

    func testUnreadableStoredDataIsDiscardedButStorageFailureIsNot() async throws {
        let corrupted = Harness(stored: AuthFixtures.storedTokens)
        corrupted.store.failLoad(with: .corrupted)
        let member = try await corrupted.repository.restoreSession()
        XCTAssertNil(member)
        XCTAssertNil(corrupted.store.tokens)

        let failing = Harness(stored: AuthFixtures.storedTokens)
        failing.store.failLoad(with: .failure(status: -25308))
        await expect(.unavailable) { try await failing.repository.restoreSession() }
        XCTAssertEqual(failing.store.tokens, AuthFixtures.storedTokens)
        XCTAssertEqual(failing.api.recordedCalls, [])
    }

    // MARK: - Logout

    func testLogoutDeletesCredentials() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        try await harness.repository.logout()
        XCTAssertNil(harness.store.tokens)
    }

    func testLogoutFailureKeepsSessionAndReportsFailure() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.store.failDelete(with: .failure(status: -1))
        await expect(.logoutFailed) { try await harness.repository.logout() }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)

        harness.store.failDelete(with: nil)
        try await harness.repository.logout()
        XCTAssertNil(harness.store.tokens)
    }

    func testLogoutDiscardsPendingSignup() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        try await harness.repository.logout()
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
    }

    // MARK: - Cancellation and late results

    func testCancelledSignInDoesNotStoreLateResult() async {
        let harness = Harness()
        let gate = Suspension()
        harness.api.onSocialLogin = { _ in
            await gate.suspend()
            return AuthFixtures.session(account: AuthFixtures.completedAccount)
        }
        let task = Task { try await harness.repository.signInWithGoogle() }
        await gate.waitUntilEntered()

        task.cancel()
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
    }

    func testDiscardThenFlagOnSuppressesLateSignInResult() async throws {
        let harness = Harness()
        let gate = Suspension()
        harness.api.onSocialLogin = { _ in
            await gate.suspend()
            return AuthFixtures.session(account: AuthFixtures.completedAccount)
        }
        let task = Task { try await harness.repository.signInWithGoogle() }
        await gate.waitUntilEntered()

        harness.flag.mutate { $0 = false }
        try await harness.repository.discardPendingSignup()
        harness.flag.mutate { $0 = true }
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
        XCTAssertEqual(harness.store.saveCount, 0)
    }

    func testLogoutSuppressesLateSignInResult() async throws {
        let harness = Harness()
        let gate = Suspension()
        harness.api.onSocialLogin = { _ in
            await gate.suspend()
            return AuthFixtures.session(account: AuthFixtures.completedAccount)
        }
        let task = Task { try await harness.repository.signInWithGoogle() }
        await gate.waitUntilEntered()

        try await harness.repository.logout()
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
        XCTAssertEqual(harness.store.saveCount, 0)
    }

    func testDiscardSuppressesLateSignupSubmissionResult() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let gate = Suspension()
        harness.api.onOnboarding = { _, _ in
            await gate.suspend()
            return AuthFixtures.completedAccount
        }
        let task = Task { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await gate.waitUntilEntered()

        try await harness.repository.discardPendingSignup()
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
        await expect(.noPendingSignup) { try await harness.repository.checkSignupCompletion() }
    }

    func testLateSubmissionErrorAfterDiscardDoesNotLeakUncertainState() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let gate = Suspension()
        harness.api.onOnboarding = { _, _ in
            await gate.suspend()
            throw AuthRemoteError.connection
        }
        let task = Task { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await gate.waitUntilEntered()

        try await harness.repository.discardPendingSignup()
        await gate.open()

        await expectCancellation { try await task.value }
        await expect(.noPendingSignup) { try await harness.repository.checkSignupCompletion() }
    }

    func testCancelledSubmissionRequiresRecheckBecauseServerMayHaveCompleted() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let gate = Suspension()
        harness.api.onOnboarding = { _, _ in
            await gate.suspend()
            return AuthFixtures.completedAccount
        }
        let task = Task { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await gate.waitUntilEntered()

        task.cancel()
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
        let outcome = try await harness.repository.checkSignupCompletion()
        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
    }

    func testLogoutSuppressesLateRestoreRefresh() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        let gate = Suspension()
        harness.api.onFetchAccount = { token in
            if token == AuthFixtures.storedTokens.accessToken { throw AuthRemoteError.unauthorized }
            return AuthFixtures.completedAccount
        }
        harness.api.onRefresh = { _ in
            await gate.suspend()
            return "new-access"
        }
        let task = Task { try await harness.repository.restoreSession() }
        await gate.waitUntilEntered()

        try await harness.repository.logout()
        await gate.open()

        await expectCancellation { try await task.value }
        XCTAssertNil(harness.store.tokens)
        XCTAssertEqual(harness.store.saveCount, 0)
        XCTAssertEqual(harness.api.count(of: "fetchAccount"), 1)
    }

    func testCancelledRestoreKeepsStoredCredentials() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        let gate = Suspension()
        harness.api.onFetchAccount = { _ in
            await gate.suspend()
            throw AuthRemoteError.unauthorized
        }
        harness.api.onRefresh = { _ in throw AuthRemoteError.unauthorized }
        let task = Task { try await harness.repository.restoreSession() }
        await gate.waitUntilEntered()

        task.cancel()
        await gate.open()

        await expectCancellation { try await task.value }
        // An invalid-credential answer that arrives after cancellation must not delete anything.
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testNewSignInInvalidatesPendingSignup() async throws {
        let harness = Harness()
        try await signedInAwaitingSignup(harness)
        let gate = Suspension()
        harness.api.onSocialLogin = { _ in
            await gate.suspend()
            return AuthFixtures.session(account: AuthFixtures.incompleteAccount)
        }
        let task = Task { try await harness.repository.signInWithGoogle() }
        await gate.waitUntilEntered()

        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await gate.open()
        _ = try await task.value
    }

    // MARK: - Feature flag

    func testDisabledFlagBlocksEveryOperationAndKeepsStoredCredentials() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.flag.mutate { $0 = false }

        await expect(.featureUnavailable) { try await harness.repository.restoreSession() }
        await expect(.featureUnavailable) { try await harness.repository.signInWithGoogle() }
        await expect(.featureUnavailable) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await expect(.featureUnavailable) { try await harness.repository.checkSignupCompletion() }
        await expect(.featureUnavailable) { try await harness.repository.logout() }

        XCTAssertEqual(harness.api.recordedCalls, [])
        XCTAssertEqual(harness.google.callCount, 0)
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testFlagTurnedOffDuringSignInSuppressesTheResultAndPendingSignup() async throws {
        let harness = Harness()
        let gate = Suspension()
        harness.api.onSocialLogin = { _ in
            await gate.suspend()
            return AuthFixtures.session(account: AuthFixtures.completedAccount)
        }
        let task = Task { try await harness.repository.signInWithGoogle() }
        await gate.waitUntilEntered()

        harness.flag.mutate { $0 = false }
        await gate.open()

        do {
            _ = try await task.value
            XCTFail("Expected featureUnavailable")
        } catch {
            XCTAssertEqual(error as? AuthError, .featureUnavailable)
        }
        XCTAssertNil(harness.store.tokens)
    }

    func testFlagTurnedOffDuringRestoreKeepsCredentialsEvenWhenServerSaysInvalid() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        let gate = Suspension()
        harness.api.onFetchAccount = { _ in
            await gate.suspend()
            throw AuthRemoteError.unauthorized
        }
        harness.api.onRefresh = { _ in throw AuthRemoteError.unauthorized }
        let task = Task { try await harness.repository.restoreSession() }
        await gate.waitUntilEntered()

        harness.flag.mutate { $0 = false }
        await gate.open()

        do {
            _ = try await task.value
            XCTFail("Expected featureUnavailable")
        } catch {
            XCTAssertEqual(error as? AuthError, .featureUnavailable)
        }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }
    func testCancellationDuringSynchronousSaveRestoresPreviousCredentials() async throws {
        for previous in [nil, AuthFixtures.storedTokens] {
            let harness = Harness(stored: previous)
            let gate = CredentialSaveGate()
            harness.store.beforeSave = { gate.blockFirstSave() }
            harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
            let task = Task.detached { try await harness.repository.signInWithGoogle() }
            await fulfillment(of: [gate.entered], timeout: 5)
            task.cancel()
            gate.open()
            let result = await task.result
            XCTAssertEqual(harness.store.tokens, previous)
            await expectCancellation { try result.get() }
            try await harness.repository.discardPendingSignup()
            harness.api.onFetchAccount = { token in
                XCTAssertEqual(token, AuthFixtures.storedTokens.accessToken)
                return AuthFixtures.completedAccount
            }
            let restored = try await harness.repository.restoreSession()
            XCTAssertEqual(restored, previous == nil ? nil : Member(nickname: "수연"))
        }
    }

    func testMalformedAccountRecheckCannotUnlockAnotherOnboardingPost() async throws {
        let malformed = [
            #"{}"#,
            #"{"id":1,"nickname":"fixture"}"#,
            #"{"id":1,"onboardingCompletedAt":null}"#,
            #"{"id":-1,"nickname":"fixture","onboardingCompletedAt":null}"#,
            #"{"id":1,"nickname":"fixture","onboardingCompletedAt":"garbage"}"#
        ]
        for json in malformed {
            let harness = Harness()
            try await signedInAwaitingSignup(harness)
            harness.api.onOnboarding = { _, _ in throw AuthRemoteError.connection }
            await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            harness.api.onFetchAccount = { _ in
                do { return try JSONDecoder().decode(AccountDTO.self, from: Data(json.utf8)) }
                catch { throw AuthRemoteError.server }
            }
            await expect(.unavailable) { try await harness.repository.checkSignupCompletion() }
            await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
            XCTAssertNil(harness.store.tokens)
            harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
            let outcome = try await harness.repository.checkSignupCompletion()
            XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        }
    }

    func testMalformedLoginAccountNeverStoresCredentialsOrStartsSignup() async {
        let malformed = [
            #"{}"#,
            #"{"nickname":"fixture","onboardingCompletedAt":"2026-10-01T00:00:00Z"}"#,
            #"{"id":-1,"nickname":"fixture","onboardingCompletedAt":"2026-10-01T00:00:00Z"}"#,
            #"{"id":1,"nickname":"fixture","onboardingCompletedAt":"garbage"}"#,
            #"{"id":1,"nickname":"fixture"}"#,
            #"{"id":1,"onboardingCompletedAt":"2026-10-01T00:00:00Z"}"#
        ]
        for json in malformed {
            let harness = Harness()
            harness.api.onSocialLogin = { _ in
                do {
                    let account = try JSONDecoder().decode(AccountDTO.self, from: Data(json.utf8))
                    return AuthFixtures.session(account: account)
                } catch { throw AuthAPIClient.classify(error) }
            }
            await expect(.unavailable) { try await harness.repository.signInWithGoogle() }
            await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            XCTAssertNil(harness.store.tokens)
            XCTAssertEqual(harness.store.saveCount, 0)
        }
    }

    func testEmptyTokensNeverStoreOrAuthorizeSignup() async {
        for access in ["", "  ", "valid"] {
            let harness = Harness()
            harness.api.onSocialLogin = { _ in
                AuthSessionDTO(accessToken: access, refreshToken: access == "valid" ? "" : "valid",
                               account: AuthFixtures.completedAccount, suggestedNickname: nil)
            }
            await expect(.unavailable) { try await harness.repository.signInWithGoogle() }
            XCTAssertNil(harness.store.tokens)
            XCTAssertEqual(harness.store.saveCount, 0)
        }
    }

    func testEmptyRefreshTokenResponseDoesNotRepeatAuthorizedRequestOrOverwriteCredentials() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        harness.api.onRefresh = { _ in " " }
        await expect(.unavailable) { try await harness.repository.restoreSession() }
        XCTAssertEqual(harness.api.count(of: "fetchAccount"), 1)
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testMismatchedSignupIdentityStaysUncertainAndNeverResubmits() async throws {
        for completedAt: String? in [nil, "2026-10-01T00:00:00Z"] {
            let harness = Harness()
            try await signedInAwaitingSignup(harness)
            let wrong = AccountDTO(id: 2, nickname: "other", onboardingCompletedAt: completedAt)
            harness.api.onOnboarding = { _, _ in wrong }
            await expect(.signupStatusUnknown) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            harness.api.onFetchAccount = { _ in wrong }
            await expect(.unavailable) { try await harness.repository.checkSignupCompletion() }
            await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
            XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
            XCTAssertNil(harness.store.tokens)
            harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
            let outcome = try await harness.repository.checkSignupCompletion()
            XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        }
    }

    func testMalformedRestoreKeepsPreviouslyConfirmedCredentials() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.api.onFetchAccount = { _ in
            do { return try JSONDecoder().decode(AccountDTO.self, from: Data("{}".utf8)) }
            catch { throw AuthAPIClient.classify(error) }
        }
        await expect(.unavailable) { try await harness.repository.restoreSession() }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    private func verifyInterruptedWrite(
        afterStage: Bool = false, finalCommit: Bool = false, turnOff: Bool = false,
        cleanupFails: Bool = false
    ) async throws {
        for previous in [nil, AuthFixtures.storedTokens] {
            let harness = Harness(stored: previous)
            let gate = CredentialSaveGate()
            if finalCommit { harness.store.beforeCommit = { gate.blockFirstSave() } }
            else if afterStage { harness.store.afterSave = { gate.blockFirstSave() } }
            else { harness.store.beforeSave = { gate.blockFirstSave() } }
            if cleanupFails { harness.store.failDiscard(with: .failure(status: -1)) }
            harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
            let task = Task.detached { try await harness.repository.signInWithGoogle() }
            await fulfillment(of: [gate.entered], timeout: 5)
            if turnOff { harness.flag.mutate { $0 = false } } else { task.cancel() }
            gate.open()
            let result = await task.result
            let returnedMember: Bool
            if case .success(.member) = result { returnedMember = true } else { returnedMember = false }
            print("WRITE-TRACE final=\(finalCommit) afterStage=\(afterStage) OFF=\(turnOff) prior=\(previous != nil) cleanupFails=\(cleanupFails) returnedMember=\(returnedMember) priorPreserved=\(harness.store.tokens == previous) pending=\(harness.store.hasPendingWrite)")
            XCTAssertEqual(harness.store.tokens, previous)
            if turnOff { await expect(.featureUnavailable) { try result.get() } }
            else { await expectCancellation { try result.get() } }
            harness.flag.mutate { $0 = true }
            let fresh = DefaultAuthRepository(api: harness.api, google: harness.google, store: harness.store, isFeatureEnabled: { true })
            harness.api.onFetchAccount = { token in
                XCTAssertEqual(token, AuthFixtures.storedTokens.accessToken)
                return AuthFixtures.completedAccount
            }
            let restored = try await fresh.restoreSession()
            XCTAssertEqual(restored, previous == nil ? nil : Member(nickname: "수연"))
        }
    }

    func testCancellationAfterStageBeforeCommitPreservesPriorCredentials() async throws {
        try await verifyInterruptedWrite(afterStage: true)
    }

    func testCancellationDuringFinalCommitPreservesPriorCredentials() async throws {
        try await verifyInterruptedWrite(finalCommit: true)
    }

    func testFlagOffDuringFinalCommitPreservesPriorCredentials() async throws {
        try await verifyInterruptedWrite(finalCommit: true, turnOff: true)
    }

    func testPendingCleanupFailureCannotRestoreCancelledStageInFreshRepository() async throws {
        try await verifyInterruptedWrite(cleanupFails: true)
    }

    func testFinalCommitFailurePreservesPriorCredentialsAndDoesNotReturnMember() async {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.store.failCommit(with: .failure(status: -1))
        harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
        await expect(.unavailable) { try await harness.repository.signInWithGoogle() }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testSuccessfulCommitStillReturnsMemberWhenPendingCleanupFails() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        harness.store.failDiscard(with: .failure(status: -1))
        harness.api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
        let outcome = try await harness.repository.signInWithGoogle()
        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        XCTAssertEqual(harness.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertTrue(harness.store.hasPendingWrite)
    }

    func testActualStoreCompensationFailureBlocksFreshRestorationUntilRecovery() async throws {
        for previous in [nil, AuthFixtures.storedTokens] {
            let persistence = InMemoryCredentialPersistence()
            if let previous { try persistence.write(JSONEncoder().encode(previous), account: "session") }
            let store = KeychainCredentialStore(persistence: persistence)
            let api = FakeAuthAPI(), google = FakeGoogle(), flag = Locked(true)
            let repository = DefaultAuthRepository(api: api, google: google, store: store, isFeatureEnabled: { flag.read { $0 } })
            api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
            let gate = CredentialSaveGate()
            persistence.beforeWrite = { account in if account == "session" { gate.blockFirstSave() } }
            let task = Task.detached { try await repository.signInWithGoogle() }
            await fulfillment(of: [gate.entered], timeout: 5)
            task.cancel()
            // The entered commit finishes; only its subsequent compensation is failed.
            persistence.failWrites(to: ["session"])
            persistence.failDeletes(to: ["session"])
            gate.open()
            let result = await task.result
            await expect(.unavailable) { try result.get() }
            flag.mutate { $0 = false }
            await expect(.unavailable) { try await repository.discardPendingSignup() }
            let freshStore = KeychainCredentialStore(persistence: persistence)
            XCTAssertThrowsError(try freshStore.load())
            let fresh = DefaultAuthRepository(api: api, google: google, store: freshStore, isFeatureEnabled: { true })
            await expect(.unavailable) { try await fresh.restoreSession() }
            XCTAssertEqual(api.count(of: "fetchAccount"), 0)
            print("RECOVERY-TRACE prior=\(previous != nil) operation=unavailable invalidation=failed freshLoad=failed network=0")
            persistence.failWrites(to: [])
            persistence.failDeletes(to: [])
            // Explicit invalidation may compensate this attempt even while OFF.
            try await repository.discardPendingSignup()
            XCTAssertEqual(try freshStore.load(), previous)
            api.onFetchAccount = { token in
                XCTAssertEqual(token, AuthFixtures.storedTokens.accessToken)
                return AuthFixtures.completedAccount
            }
            let restored = try await fresh.restoreSession()
            XCTAssertEqual(restored, previous == nil ? nil : Member(nickname: "수연"))
        }
    }

    func testCancelledRefreshDuringFinalCommitPreservesCompletedCredentials() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        let gate = CredentialSaveGate()
        harness.store.beforeCommit = { gate.blockFirstSave() }
        harness.api.onFetchAccount = { token in
            if token == AuthFixtures.storedTokens.accessToken { throw AuthRemoteError.unauthorized }
            return AuthFixtures.completedAccount
        }
        harness.api.onRefresh = { _ in "fresh-access" }
        let task = Task.detached { try await harness.repository.restoreSession() }
        await fulfillment(of: [gate.entered], timeout: 5)
        task.cancel()
        gate.open()
        await expectCancellation { try await task.value }
        try await harness.repository.discardPendingSignup()
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
    }

    func testCancelledSignupFinalCommitRequiresRecheckWithoutResubmission() async throws {
        let harness = Harness(stored: AuthFixtures.storedTokens)
        try await signedInAwaitingSignup(harness)
        let gate = CredentialSaveGate()
        harness.store.beforeCommit = { gate.blockFirstSave() }
        harness.api.onOnboarding = { _, _ in AuthFixtures.completedAccount }
        let task = Task.detached { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        await fulfillment(of: [gate.entered], timeout: 5)
        task.cancel()
        gate.open()
        await expectCancellation { try await task.value }
        XCTAssertEqual(harness.store.tokens, AuthFixtures.storedTokens)
        await expect(.noPendingSignup) { try await harness.repository.completeSignup(AuthFixtures.registration()) }
        harness.api.onFetchAccount = { _ in AuthFixtures.completedAccount }
        let outcome = try await harness.repository.checkSignupCompletion()
        XCTAssertEqual(outcome, .member(Member(nickname: "수연")))
        XCTAssertEqual(harness.api.count(of: "onboarding"), 1)
    }

    func testAwaitedInvalidationDuringFinalCommitSurvivesOffThenOnWithoutTaskCancellation() async throws {
        let api = FakeAuthAPI(), google = FakeGoogle()
        let store = FakeCredentialStore(tokens: AuthFixtures.storedTokens)
        let flag = Locked(true), clock = ObservedAuthInvalidationClock()
        let repository = DefaultAuthRepository(api: api, google: google, store: store,
            isFeatureEnabled: { flag.read { $0 } }, invalidation: clock)
        let gate = CredentialSaveGate()
        store.beforeCommit = { gate.blockFirstSave() }
        api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
        let task = Task.detached { try await repository.signInWithGoogle() }
        await fulfillment(of: [gate.entered], timeout: 5)
        let invalidationEntered = XCTestExpectation(description: "Invalidation signalled before actor wait")
        clock.onAdvance.mutate { $0 = { invalidationEntered.fulfill() } }
        flag.mutate { $0 = false }
        let invalidation = Task.detached { try await repository.discardPendingSignup() }
        await fulfillment(of: [invalidationEntered], timeout: 5)
        flag.mutate { $0 = true }
        gate.open()
        await expectCancellation { try await task.value }
        try await invalidation.value
        XCTAssertEqual(store.tokens, AuthFixtures.storedTokens)
        print("INVALIDATION-TRACE finalCommit=true taskCancelled=false OFFthenON=true acknowledged=true priorPreserved=true")
    }

    func testInvalidationBeforeFinalPublicationCompensatesEvenAfterPendingCleanup() async throws {
        let api = FakeAuthAPI(), google = FakeGoogle()
        let store = FakeCredentialStore(tokens: AuthFixtures.storedTokens)
        let clock = ObservedAuthInvalidationClock()
        let repository = DefaultAuthRepository(api: api, google: google, store: store,
            isFeatureEnabled: { true }, invalidation: clock)
        let gate = CredentialSaveGate()
        clock.beforeComplete.mutate { $0 = { gate.blockFirstSave() } }
        api.onSocialLogin = { _ in AuthFixtures.session(account: AuthFixtures.completedAccount) }
        let task = Task.detached { try await repository.signInWithGoogle() }
        await fulfillment(of: [gate.entered], timeout: 5)
        let signalled = XCTestExpectation(description: "Invalidation before publication")
        clock.onAdvance.mutate { $0 = { signalled.fulfill() } }
        let invalidation = Task.detached { try await repository.discardPendingSignup() }
        await fulfillment(of: [signalled], timeout: 5)
        gate.open()
        await expectCancellation { try await task.value }
        try await invalidation.value
        XCTAssertEqual(store.tokens, AuthFixtures.storedTokens)
    }

}

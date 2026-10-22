import XCTest
@testable import studyclub

final class MemberAuthorizationTests: XCTestCase {
    private struct Harness {
        let api = FakeAuthAPI()
        let store: FakeCredentialStore
        let flag = Locked(true)
        let auth: DefaultAuthRepository

        init(tokens: AuthTokens? = AuthFixtures.sessionTokens) {
            let api = api, flag = flag
            let store = FakeCredentialStore(tokens: tokens)
            self.store = store
            auth = DefaultAuthRepository(api: api, google: FakeGoogle(), store: store,
                                         isFeatureEnabled: { flag.read { $0 } })
        }
    }

    func testAuthOffPreservesCredentialsAndDoesNotCallMemberOperation() async {
        let h = Harness()
        h.flag.mutate { $0 = false }
        let calls = Locked(0)
        do {
            _ = try await h.auth.withAuthorization { _ in calls.mutate { $0 += 1 }; return 1 }
            XCTFail("Expected featureUnavailable")
        } catch { XCTAssertEqual(error as? AuthError, .featureUnavailable) }
        XCTAssertEqual(calls.read { $0 }, 0)
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
    }

    func testNoCompletedCredentialsDoesNotCallMemberOperation() async {
        let h = Harness(tokens: nil)
        let calls = Locked(0)
        do {
            _ = try await h.auth.withAuthorization { _ in calls.mutate { $0 += 1 }; return 1 }
            XCTFail("Expected authenticationInvalid")
        } catch { XCTAssertEqual(error as? AuthError, .authenticationInvalid) }
        XCTAssertEqual(calls.read { $0 }, 0)
        XCTAssertTrue(h.api.recordedCalls.isEmpty)
    }

    func testRejectedAccessRefreshesOnceAndCommitsNewToken() async throws {
        let h = Harness()
        h.api.onRefresh = { _ in "new-access" }
        let seen = Locked<[String]>([])
        let result = try await h.auth.withAuthorization { token in
            seen.mutate { $0.append(token) }
            if token != "new-access" { throw AuthRemoteError.unauthorized }
            return "member-value"
        }
        XCTAssertEqual(result, "member-value")
        XCTAssertEqual(seen.read { $0 }, [AuthFixtures.sessionTokens.accessToken, "new-access"])
        XCTAssertEqual(h.api.count(of: "refresh"), 1)
        XCTAssertEqual(h.store.tokens?.accessToken, "new-access")
    }

    func testRefreshConnectionFailureKeepsCompletedCredentials() async {
        let h = Harness()
        h.api.onRefresh = { _ in throw AuthRemoteError.connection }
        do {
            let _: Int = try await h.auth.withAuthorization { _ in throw AuthRemoteError.unauthorized }
            XCTFail("Expected connectionFailure")
        } catch { XCTAssertEqual(error as? AuthError, .connectionFailure) }
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
    }

    func testOnboardingRequiredDoesNotRefreshOrDeleteCredentials() async {
        let h = Harness()
        do {
            let _: Int = try await h.auth.withAuthorization { _ in throw RepositoryError.onboardingRequired }
            XCTFail("Expected onboardingRequired")
        } catch { XCTAssertEqual(error as? RepositoryError, .onboardingRequired) }
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertEqual(h.api.count(of: "refresh"), 0)
    }

    func testLogoutInvalidatesSuspendedMemberResult() async throws {
        let h = Harness()
        let barrier = Suspension()
        let request = Task {
            try await h.auth.withAuthorization { _ in await barrier.suspend(); return "private-value" }
        }
        await barrier.waitUntilEntered()
        try await h.auth.logout()
        await barrier.open()
        do { _ = try await request.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(h.store.tokens)
    }

    func testCancelledMemberOperationCannotCommitRefreshedCredentials() async {
        let h = Harness()
        let barrier = Suspension()
        h.api.onRefresh = { _ in await barrier.suspend(); return "late-access" }
        let request = Task {
            let _: Int = try await h.auth.withAuthorization { _ in throw AuthRemoteError.unauthorized }
        }
        await barrier.waitUntilEntered()
        request.cancel()
        await barrier.open()
        do { try await request.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
    }

    func testLogoutBeforeLateRefreshCannotRestoreDeletedCredentials() async throws {
        let h = Harness()
        let barrier = Suspension()
        h.api.onRefresh = { _ in await barrier.suspend(); return "late-access" }
        let request = Task {
            let _: Int = try await h.auth.withAuthorization { _ in throw AuthRemoteError.unauthorized }
        }
        await barrier.waitUntilEntered()
        try await h.auth.logout()
        XCTAssertNil(h.store.tokens)
        await barrier.open()
        do { try await request.value; XCTFail("Expected cancellation") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(h.store.tokens)
        XCTAssertEqual(h.store.saveCount, 0)
    }

    func testListOffStopsBeforeSharedAuthorization() async {
        let h = Harness()
        let repository = Repository(authorization: h.auth, isMyStudiesAPIEnabled: false)
        do { _ = try await repository.fetchMyStudies(); XCTFail("Expected featureUnavailable") }
        catch { XCTAssertEqual(error as? RepositoryError, .featureUnavailable) }
        XCTAssertTrue(h.api.recordedCalls.isEmpty)
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
    }

    func testSessionRejectionInvalidatesOtherConsumersLateRefresh() async throws {
        let h = Harness()
        let barrier = Suspension()
        let refreshes = Locked(0)
        h.api.onRefresh = { _ in
            let call = refreshes.mutate { $0 += 1; return $0 }
            if call == 1 { await barrier.suspend(); return "late-access" }
            throw AuthRemoteError.unauthorized
        }
        h.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        let list = Task {
            try await h.auth.withAuthorization { token in
                if token == "late-access" { return "private-list" }
                throw AuthRemoteError.unauthorized
            }
        }
        await barrier.waitUntilEntered()
        let session = try await h.auth.restoreSession()
        XCTAssertNil(session)
        XCTAssertNil(h.store.tokens)
        await barrier.open()
        do { _ = try await list.value; XCTFail("Invalidated session returned late private content") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertNil(h.store.tokens)
        XCTAssertEqual(h.store.saveCount, 0)
    }

    func testFailedSessionDeletionStillInvalidatesLateRefreshAndPreservesFailure() async throws {
        let h = Harness()
        let barrier = Suspension()
        let refreshes = Locked(0)
        h.store.failDelete(with: .failure(status: -1))
        h.api.onRefresh = { _ in
            let call = refreshes.mutate { $0 += 1; return $0 }
            if call == 1 { await barrier.suspend(); return "late-access" }
            throw AuthRemoteError.unauthorized
        }
        h.api.onFetchAccount = { _ in throw AuthRemoteError.unauthorized }
        let list = Task {
            try await h.auth.withAuthorization { token in
                if token == "late-access" { return "private-list" }
                throw AuthRemoteError.unauthorized
            }
        }
        await barrier.waitUntilEntered()
        do { _ = try await h.auth.restoreSession(); XCTFail("Expected failed invalidation") }
        catch { XCTAssertEqual(error as? AuthError, .unavailable) }
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
        await barrier.open()
        do { _ = try await list.value; XCTFail("Expected cancellation after invalidation attempt") }
        catch { XCTAssertTrue(error is CancellationError) }
        XCTAssertEqual(h.store.tokens, AuthFixtures.sessionTokens)
        XCTAssertEqual(h.store.saveCount, 0)
    }
}

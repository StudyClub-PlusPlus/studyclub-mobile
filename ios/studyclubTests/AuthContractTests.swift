import Alamofire
import XCTest
@testable import studyclub

final class AuthContractTests: XCTestCase {
    func testGoogleSocialLoginSendsEmptyRedirectURI() throws {
        let request = try AuthRouter.socialLogin(
            SocialAuthorization(provider: .google, code: "one-time-code")
        ).asURLRequest()
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]

        XCTAssertEqual(request.url?.absoluteString, "https://api.studyclub-plusplus.com/auth/social-login")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(body?["code"], "one-time-code")
        XCTAssertEqual(body?["provider"], "google")
        XCTAssertEqual(body?["platform"], "CORE")
        // The SDK's serverAuthCode has no callback; omitting it would make the server use the web one.
        XCTAssertEqual(body?["redirectUri"], "")
        XCTAssertNil(body?["name"])
        XCTAssertNil(request.value(forHTTPHeaderField: "Authorization"))
    }

    func testAppleSocialLoginSendsNameWithoutRedirectURI() throws {
        let request = try AuthRouter.socialLogin(
            SocialAuthorization(provider: .apple, code: "apple-code", name: "홍길동")
        ).asURLRequest()
        let body = try JSONSerialization.jsonObject(with: XCTUnwrap(request.httpBody)) as? [String: String]

        XCTAssertEqual(body?["provider"], "apple")
        XCTAssertEqual(body?["code"], "apple-code")
        XCTAssertEqual(body?["name"], "홍길동")
        XCTAssertNil(body?["redirectUri"])
    }

    func testRefreshMeAndOnboardingRoutes() throws {
        let refresh = try AuthRouter.refresh(refreshToken: "refresh-token").asURLRequest()
        let me = try AuthRouter.me(accessToken: "access-token").asURLRequest()
        let onboarding = try AuthRouter.onboarding(
            accessToken: "access-token",
            body: OnboardingRequestDTO(AuthFixtures.registration(nickname: " 새닉네임 "))
        ).asURLRequest()
        let onboardingBody = try JSONSerialization.jsonObject(with: XCTUnwrap(onboarding.httpBody)) as? [String: Any]

        XCTAssertEqual(refresh.url?.absoluteString, "https://api.studyclub-plusplus.com/auth/refresh")
        XCTAssertEqual(me.url?.absoluteString, "https://api.studyclub-plusplus.com/auth/me")
        XCTAssertEqual(me.httpMethod, "GET")
        XCTAssertEqual(me.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
        XCTAssertEqual(onboarding.url?.absoluteString, "https://api.studyclub-plusplus.com/accounts/onboarding")
        XCTAssertEqual(onboardingBody?["nickname"] as? String, "새닉네임")
        XCTAssertEqual(onboardingBody?["timeZone"] as? String, "Asia/Seoul")
        XCTAssertEqual(onboardingBody?["marketingAgreed"] as? Bool, false)
        XCTAssertEqual(onboarding.value(forHTTPHeaderField: "Authorization"), "Bearer access-token")
    }

    func testAccountShapesDecodeAndMapOnlyAConfirmedNickname() throws {
        let login = try JSONDecoder().decode(
            AuthSessionDTO.self,
            from: Data(#"{"accessToken":"a","refreshToken":"r","account":{"id":1,"nickname":"수연","onboardingCompletedAt":"2026-10-01T00:00:00Z"},"suggestedNickname":"구글"}"#.utf8)
        )
        let me = try JSONDecoder().decode(
            AccountDTO.self,
            from: Data(#"{"id":1,"nickname":"수연","onboardingCompletedAt":"2026-10-01T00:00:00Z","discordNickname":"su"}"#.utf8)
        )
        let incomplete = try JSONDecoder().decode(
            AccountDTO.self,
            from: Data(#"{"id":1,"nickname":"account_abc","onboardingCompletedAt":null,"discordNickname":null}"#.utf8)
        )

        XCTAssertEqual(try login.account.toMember(), Member(nickname: "수연"))
        XCTAssertEqual(try me.toMember(), Member(nickname: "수연"))
        XCTAssertEqual(me.discordNickname, "su")
        XCTAssertNil(try incomplete.toMember())
        XCTAssertThrowsError(try AccountDTO(id: 1, nickname: " ", onboardingCompletedAt: "2026-10-01T00:00:00Z").toMember()) { error in
            XCTAssertEqual(error as? AuthRemoteError, .server)
        }
    }

    func testRemoteErrorClassification() {
        XCTAssertEqual(AuthAPIClient.classify(status: 401), .unauthorized)
        XCTAssertEqual(AuthAPIClient.classify(status: 400), .badRequest)
        XCTAssertEqual(AuthAPIClient.classify(status: 422), .badRequest)
        XCTAssertEqual(AuthAPIClient.classify(status: 409), .conflict)
        XCTAssertEqual(AuthAPIClient.classify(status: 500), .server)

        XCTAssertTrue(AuthAPIClient.classify(URLError(.cancelled)) is CancellationError)
        XCTAssertEqual(AuthAPIClient.classify(URLError(.notConnectedToInternet)) as? AuthRemoteError, .connection)
        XCTAssertTrue(AuthAPIClient.classify(AFError.explicitlyCancelled) is CancellationError)
        let rejected = AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 401))
        XCTAssertEqual(AuthAPIClient.classify(rejected) as? AuthRemoteError, .unauthorized)
    }

    func testGoogleConfigurationRequiresClientServerAndCallbackScheme() {
        let clientID = "123-abc.apps.googleusercontent.com"
        let scheme = "com.googleusercontent.apps.123-abc"
        XCTAssertEqual(GoogleSignInConfiguration.reversedScheme(of: clientID), scheme)

        let ready: [String: Any] = [
            "GIDClientID": clientID,
            "GIDServerClientID": "server.apps.googleusercontent.com",
            "CFBundleURLTypes": [["CFBundleURLSchemes": [scheme]]]
        ]
        XCTAssertEqual(GoogleSignInConfiguration(infoDictionary: ready)?.clientID, clientID)

        var missingScheme = ready
        missingScheme["CFBundleURLTypes"] = [["CFBundleURLSchemes": ["other"]]]
        XCTAssertNil(GoogleSignInConfiguration(infoDictionary: missingScheme))
        XCTAssertNil(GoogleSignInConfiguration(infoDictionary: ["GIDClientID": clientID]))
        XCTAssertNil(GoogleSignInConfiguration(infoDictionary: [:]))

        // Checked-in default unconfigured shape:
        // GID_CLIENT_ID and GID_SERVER_CLIENT_ID are empty;
        // GID_REVERSED_CLIENT_ID is a safe nonempty placeholder ("studyclub.oauth-unconfigured").
        let checkedInDefault: [String: Any] = [
            "GIDClientID": "",
            "GIDServerClientID": "",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["studyclub.oauth-unconfigured"]]]
        ]
        XCTAssertNil(GoogleSignInConfiguration(infoDictionary: checkedInDefault))

        // Even if a valid client ID is provided without updating the URL scheme, placeholder scheme must mismatch
        let mismatchedPlaceholder: [String: Any] = [
            "GIDClientID": clientID,
            "GIDServerClientID": "server.apps.googleusercontent.com",
            "CFBundleURLTypes": [["CFBundleURLSchemes": ["studyclub.oauth-unconfigured"]]]
        ]
        XCTAssertNil(GoogleSignInConfiguration(infoDictionary: mismatchedPlaceholder))

        // Non-standard scheme names without the Google suffix cannot produce a reversed scheme
        XCTAssertNil(GoogleSignInConfiguration.reversedScheme(of: "studyclub.oauth-unconfigured"))
        XCTAssertNil(GoogleSignInConfiguration.reversedScheme(of: ""))
    }

    func testKeychainRoundTripAndMissingItem() throws {
        let store = KeychainCredentialStore(service: "studycub.studyclub.auth.tests.\(UUID().uuidString)")
        addTeardownBlock { try? store.delete() }
        let tokens = AuthTokens(accessToken: "access", refreshToken: "refresh")

        XCTAssertNil(try store.load())
        let first = try store.save(tokens)
        XCTAssertNil(try store.load())
        try store.commit(first)
        try store.discard(first)
        XCTAssertEqual(try store.load(), tokens)
        let next = try store.save(AuthTokens(accessToken: "next", refreshToken: "refresh"))
        XCTAssertEqual(try store.load(), tokens)
        try store.commit(next)
        try store.discard(next)
        XCTAssertEqual(try store.load()?.accessToken, "next")
        try store.delete()
        XCTAssertNil(try store.load())
        try store.delete()
    }
    func testAccountRequiresIdentityNicknameAndExplicitCompletion() throws {
        let malformed = [
            #"{}"#,
            #"{"nickname":"fixture","onboardingCompletedAt":null}"#,
            #"{"id":null,"nickname":"fixture","onboardingCompletedAt":null}"#,
            #"{"id":1,"onboardingCompletedAt":null}"#,
            #"{"id":1,"nickname":null,"onboardingCompletedAt":null}"#,
            #"{"id":1,"nickname":"fixture"}"#
        ]
        for json in malformed {
            XCTAssertThrowsError(try JSONDecoder().decode(AccountDTO.self, from: Data(json.utf8)))
        }
        for id: Int64 in [0, -1] {
            let dto = try JSONDecoder().decode(AccountDTO.self, from: Data("{\"id\":\(id),\"nickname\":\"fixture\",\"onboardingCompletedAt\":null}".utf8))
            XCTAssertThrowsError(try dto.toMember())
        }
    }

    func testCompletionAcceptsServerInstantPrecisionAndRejectsMalformedCalendarValues() throws {
        for value in ["2026-10-01T00:00:00Z", "2026-10-01T00:00:00.123Z",
                      "2026-10-01T00:00:00.123456Z", "2026-10-01T00:00:00.123456789Z"] {
            XCTAssertEqual(try AccountDTO(id: 1, nickname: "fixture", onboardingCompletedAt: value).toMember(), Member(nickname: "fixture"))
        }
        for value in ["", " ", "garbage", "2026-10-01", "2026-02-30T00:00:00Z",
                      "2026-10-01T25:00:00Z", "2026-10-01T00:00:00Zsuffix",
                      "2026-10-01T00:00:00.1234567890Z"] {
            XCTAssertThrowsError(try AccountDTO(id: 1, nickname: "fixture", onboardingCompletedAt: value).toMember())
        }
        XCTAssertThrowsError(try AuthFixtures.completedAccount.toMember(expectedID: 2))
        XCTAssertThrowsError(try AuthFixtures.incompleteAccount.toMember(expectedID: 2))
    }

    func testFreshKeychainStoreNeverLoadsAnUncommittedWriteAndRejectsStalePromotion() throws {
        let service = "studycub.studyclub.auth.tests.\(UUID().uuidString)"
        let store = KeychainCredentialStore(service: service)
        let fresh = KeychainCredentialStore(service: service)
        addTeardownBlock { try? store.delete() }
        let old = try store.save(AuthFixtures.storedTokens)
        try store.commit(old)
        try store.discard(old)
        let interrupted = try store.save(AuthFixtures.sessionTokens)
        addTeardownBlock { try? store.discard(interrupted) }
        XCTAssertEqual(try fresh.load(), AuthFixtures.storedTokens)
        let replacement = try fresh.save(AuthTokens(accessToken: "later", refreshToken: "later-refresh"))
        addTeardownBlock { try? fresh.discard(replacement) }
        XCTAssertThrowsError(try store.commit(interrupted))
        XCTAssertEqual(try fresh.load(), AuthFixtures.storedTokens)
        try store.discard(interrupted)
        try fresh.commit(replacement)
        XCTAssertEqual(try store.load()?.accessToken, "later")
    }

    func testActualStoreRollbackIsConditionalOnTheActiveAttempt() throws {
        let persistence = InMemoryCredentialPersistence()
        let store = KeychainCredentialStore(persistence: persistence)
        let previous = try store.save(AuthFixtures.storedTokens)
        try store.commit(previous)
        try store.discard(previous)
        let first = try store.save(AuthFixtures.sessionTokens)
        try store.commit(first)
        try store.discard(first)
        let laterTokens = AuthTokens(accessToken: "later", refreshToken: "later-refresh")
        let later = try store.save(laterTokens)
        try store.commit(later)
        try store.rollback(first)
        XCTAssertEqual(try store.load(), laterTokens)
        try store.rollback(later)
        XCTAssertEqual(try store.load(), AuthFixtures.sessionTokens)
    }

    func testActualStoreCleanupFailureKeepsCommittedSessionAndLogoutRemovesBothItems() throws {
        let persistence = InMemoryCredentialPersistence()
        let store = KeychainCredentialStore(persistence: persistence)
        let write = try store.save(AuthFixtures.sessionTokens)
        try store.commit(write)
        persistence.failDeletes(to: ["pending-session"])
        XCTAssertThrowsError(try store.discard(write))
        let fresh = KeychainCredentialStore(persistence: persistence)
        XCTAssertEqual(try fresh.load(), AuthFixtures.sessionTokens)
        XCTAssertThrowsError(try fresh.delete())
        XCTAssertEqual(try fresh.load(), AuthFixtures.sessionTokens)
        persistence.failDeletes(to: [])
        try fresh.delete()
        XCTAssertNil(try store.load())
        XCTAssertNil(try persistence.read(account: "pending-session"))
    }

}

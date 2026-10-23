import Combine
import XCTest
@testable import studyclub

@MainActor
final class MemberAreaViewModelTests: XCTestCase {
    #if DEBUG
    func testMockSignupConsentCompletesSharedMemberAreaAndLogoutClearsIt() async throws {
        // If: the actual Debug Mock graph has no member or approved production terms.
        let auth = MockAuthRepository(isFeatureEnabled: { true })
        try await auth.logout()
        let model = MemberAreaViewModel(authRepository: auth, studiesRepository: MockRepository(),
                                        isAuthEnabled: true, isListEnabled: true, isMyPageEnabled: true, isMock: true)
        await waitUntil { model.account.state == .guest }
        XCTAssertFalse(AuthDocuments().allowsConsentAndSubmit)

        // When: the user explicitly starts the mock signup and supplies required consent.
        model.account.startLogin()
        let login = try XCTUnwrap(model.account.loginViewModel)
        XCTAssertTrue(login.isMock)
        XCTAssertTrue(login.requestSignIn())
        model.account.signInWithGoogle()
        await waitUntil { model.account.presentation == .signup }
        let form = try XCTUnwrap(model.account.onboardingViewModel)
        XCTAssertTrue(form.isMock)
        XCTAssertTrue(form.allowsConsentAndSubmit)
        XCTAssertFalse(form.canSubmit, "Mock still requires explicit consent")
        XCTAssertFalse(form.input.marketingAgreed)
        form.updateNickname("로컬 회원")
        form.updateConsents(age: true, terms: true, privacy: true, marketing: false)
        model.account.submitSignup(try XCTUnwrap(form.submit()))

        // Then: the shared member list loads and logout clears the same session.
        await waitUntil { model.myStudies.state == .content }
        XCTAssertEqual(model.account.nickname, "로컬 회원")
        XCTAssertEqual(model.account.presentation, .none)
        model.account.logout()
        await waitUntil { model.account.state == .guest }
        XCTAssertTrue(model.myStudies.items.isEmpty)
        let restored = try await auth.restoreSession()
        XCTAssertNil(restored)
        XCTAssertFalse(AuthDocuments().allowsConsentAndSubmit)
    }

    func testMockSignupCloseDiscardsAttemptAndRequiresConsentAgain() async throws {
        let auth = MockAuthRepository(isFeatureEnabled: { true })
        try await auth.logout()
        let model = MemberAreaViewModel(authRepository: auth, studiesRepository: MockRepository(),
                                        isAuthEnabled: true, isListEnabled: true, isMyPageEnabled: true, isMock: true)
        await waitUntil { model.account.state == .guest }
        model.account.startLogin()
        XCTAssertTrue(model.account.loginViewModel?.requestSignIn() == true)
        model.account.signInWithGoogle()
        await waitUntil { model.account.presentation == .signup }
        let first = try XCTUnwrap(model.account.onboardingViewModel)
        first.updateConsents(age: true, terms: true, privacy: true, marketing: true)
        model.account.abandonSignup()
        await waitUntil { model.account.presentation == .none }
        XCTAssertEqual(first.state, .closed)
        XCTAssertFalse(first.input.hasRequiredConsents)
        model.account.startLogin()
        XCTAssertTrue(model.account.loginViewModel?.requestSignIn() == true)
        model.account.signInWithGoogle()
        await waitUntil { model.account.presentation == .signup }
        let next = try XCTUnwrap(model.account.onboardingViewModel)
        XCTAssertFalse(next.canSubmit)
        XCTAssertFalse(next.input.hasRequiredConsents)
        XCTAssertFalse(next.input.marketingAgreed)
    }
    #endif

    func testGuestBootstrapLeavesGuestSurfaceAndMakesNoListRequest() async {
        let auth = RootAuthStub(member: nil)
        let list = RootListStub()
        let model = root(auth, list)
        await waitUntil { model.account.state == .guest }
        XCTAssertEqual(model.myStudies.state, .guest)
        let count = await list.count
        XCTAssertEqual(count, 0)
    }

    func testConfirmedMemberLoadsListAndLogoutClearsItThroughSharedState() async {
        let auth = RootAuthStub(member: Member(nickname: "회원"))
        let list = RootListStub()
        let model = root(auth, list)
        await waitUntil { model.myStudies.state == .content }
        XCTAssertEqual(model.myStudies.items.map(\.id), ["12"])
        model.account.logout()
        await waitUntil { model.account.state == .guest }
        XCTAssertEqual(model.myStudies.state, .guest)
        XCTAssertTrue(model.myStudies.items.isEmpty)
        let count = await list.count
        XCTAssertEqual(count, 1)
    }

    func testAuthOffKeepsBothAccountAndPrivateListUnavailable() async {
        let auth = RootAuthStub(member: Member(nickname: "회원"))
        let list = RootListStub()
        let model = MemberAreaViewModel(authRepository: auth, studiesRepository: list,
                                        isAuthEnabled: false, isListEnabled: true, isMyPageEnabled: true)
        XCTAssertEqual(model.account.state, .hidden)
        XCTAssertEqual(model.myStudies.state, .unavailable)
        let restores = await auth.restoreCount
        let requests = await list.count
        XCTAssertEqual(restores, 0)
        XCTAssertEqual(requests, 0)
    }

    func testSiblingRecheckWaitsForActiveLogoutInsteadOfCancellingIt() async {
        let logout = Suspension()
        let auth = RootAuthStub(member: Member(nickname: "회원"), logoutGate: logout)
        let list = RootListStub()
        let model = root(auth, list)
        await waitUntil { model.myStudies.state == .content }
        model.account.logout()
        await logout.waitUntilEntered()
        await list.setFailure(.unauthorized)
        model.myStudies.refresh()
        await waitUntil { model.myStudies.state == .guest }
        let before = await auth.restoreCount
        XCTAssertEqual(before, 1)
        await logout.open()
        await waitUntil { model.account.state == .guest }
        for _ in 0..<100 {
            if await auth.restoreCount == 2 { break }
            await Task.yield()
        }
        let events = await auth.events
        XCTAssertEqual(events, ["restore", "logout-start", "logout-end", "restore"])
        XCTAssertEqual(model.myStudies.state, .guest)
    }

    func testRejectedListStopsAfterOneRecheckWhenAccountStillConfirmsSameMember() async {
        let secondRequest = Suspension()
        let auth = RootAuthStub(member: Member(nickname: "회원"))
        let list = RootListStub(failure: .onboardingRequired, additionalGate: secondRequest)
        let model = root(auth, list)
        await auth.waitForRestores(2)
        await waitForListState(.failure, model: model)
        let requests = await list.count
        let restores = await auth.restoreCount
        XCTAssertEqual(requests, 1, "No automatic retry of a rejected list after the same member is confirmed")
        XCTAssertEqual(restores, 2, "One shared session recheck")
        XCTAssertEqual(model.myStudies.state, .failure)
        XCTAssertTrue(model.myStudies.items.isEmpty)
        await list.setFailure(nil)
        await secondRequest.open()
        model.myStudies.refresh()
        await waitUntil { model.myStudies.state == .content }
        let retriedRequests = await list.count
        XCTAssertEqual(retriedRequests, 2, "An explicit user refresh can retry")
    }

    func testOnboardingRejectionThenGuestRecheckKeepsSpecificInstruction() async {
        let auth = RootAuthStub(member: Member(nickname: "회원"), guestAfterFirstRestore: true)
        let list = RootListStub(failure: .onboardingRequired)
        let model = root(auth, list)
        await auth.waitForRestores(2)
        await waitForAccountState(.guest, model: model)
        XCTAssertEqual(model.myStudies.state, .guest)
        XCTAssertEqual(model.myStudies.message, "가입 정보를 확인한 뒤 다시 로그인해 주세요.")
        let requests = await list.count
        XCTAssertEqual(requests, 1)
    }

    func testListRetryRepeatsFailedCleanupBeforeRestoringSharedSession() async {
        let auth = RootAuthStub(member: Member(nickname: "회원"))
        let list = RootListStub()
        let model = root(auth, list)
        await waitUntil { model.myStudies.state == .content }
        await auth.setDiscardError(.unavailable)
        do { try await model.invalidate(); XCTFail("Expected cleanup failure") } catch {}
        XCTAssertEqual(model.myStudies.state, .failure)
        model.myStudies.refresh()
        await auth.waitForDiscards(2)
        await waitForAccountState(.connectionFailure, model: model)
        let restoresBeforeRecovery = await auth.restoreCount
        XCTAssertEqual(restoresBeforeRecovery, 1, "A failed cleanup must not be bypassed by sibling refresh")
        await auth.setDiscardError(nil)
        model.myStudies.refresh()
        await waitUntil { model.myStudies.state == .content }
        let discards = await auth.discardCount
        let restores = await auth.restoreCount
        XCTAssertEqual(discards, 3)
        XCTAssertEqual(restores, 2)
    }

    private func root(_ auth: RootAuthStub, _ list: RootListStub) -> MemberAreaViewModel {
        .init(authRepository: auth, studiesRepository: list,
              isAuthEnabled: true, isListEnabled: true, isMyPageEnabled: true)
    }

    private func waitForListState(_ state: MyStudiesListViewModel.State, model: MemberAreaViewModel) async {
        var observation: AnyCancellable?
        await withCheckedContinuation { continuation in
            observation = model.myStudies.statePublisher.first(where: { $0 == state }).sink { _ in continuation.resume() }
        }
        observation?.cancel()
    }

    private func waitForAccountState(_ state: SettingAccountViewModel.State, model: MemberAreaViewModel) async {
        var observation: AnyCancellable?
        await withCheckedContinuation { continuation in
            observation = model.account.statePublisher.first(where: { $0 == state }).sink { _ in continuation.resume() }
        }
        observation?.cancel()
    }

    private func waitUntil(_ condition: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async {
        for _ in 0..<500 {
            if condition() { return }
            await Task.yield()
        }
        XCTFail("Expected shared account/list state", file: file, line: line)
    }
}

private actor RootAuthStub: AuthRepository {
    private var member: Member?
    private let logoutGate: Suspension?
    private let guestAfterFirstRestore: Bool
    private(set) var events: [String] = []
    private var restoreWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var discardWaiters: [(Int, CheckedContinuation<Void, Never>)] = []
    private var discardError: AuthError?
    private(set) var discardCount = 0
    var restoreCount: Int { events.filter { $0 == "restore" }.count }
    init(member: Member?, logoutGate: Suspension? = nil, guestAfterFirstRestore: Bool = false) {
        self.member = member
        self.logoutGate = logoutGate
        self.guestAfterFirstRestore = guestAfterFirstRestore
    }
    func restoreSession() async throws -> Member? {
        events.append("restore")
        if guestAfterFirstRestore, restoreCount > 1 { member = nil }
        let ready = restoreWaiters.filter { $0.0 <= restoreCount }
        restoreWaiters.removeAll { $0.0 <= restoreCount }
        ready.forEach { $0.1.resume() }
        return member
    }
    func waitForRestores(_ count: Int) async {
        guard restoreCount < count else { return }
        await withCheckedContinuation { restoreWaiters.append((count, $0)) }
    }
    func signInWithGoogle() async throws -> SignInOutcome { throw AuthError.configurationMissing }
    func completeSignup(_ registration: MemberRegistration) async throws -> Member { throw AuthError.noPendingSignup }
    func checkSignupCompletion() async throws -> SignInOutcome { throw AuthError.noPendingSignup }
    func setDiscardError(_ error: AuthError?) { discardError = error }
    func waitForDiscards(_ count: Int) async {
        guard discardCount < count else { return }
        await withCheckedContinuation { discardWaiters.append((count, $0)) }
    }
    func discardPendingSignup() async throws {
        discardCount += 1
        let ready = discardWaiters.filter { $0.0 <= discardCount }
        discardWaiters.removeAll { $0.0 <= discardCount }
        ready.forEach { $0.1.resume() }
        if let discardError { throw discardError }
    }
    func logout() async throws {
        events.append("logout-start")
        if let logoutGate { await logoutGate.suspend() }
        try Task.checkCancellation()
        member = nil
        events.append("logout-end")
    }
}

private actor RootListStub: RepositoryProtocol {
    private(set) var count = 0
    private var failure: RepositoryError?
    private let additionalGate: Suspension?
    init(failure: RepositoryError? = nil, additionalGate: Suspension? = nil) {
        self.failure = failure
        self.additionalGate = additionalGate
    }
    func setFailure(_ error: RepositoryError?) { failure = error }
    func fetchStudies(offset: Int) async throws -> StudyPage { throw RepositoryError.unavailable }
    func fetchStudy(id: Study.ID) async throws -> StudyDetail { throw RepositoryError.unavailable }
    func fetchMyStudies() async throws -> [MyStudy] {
        count += 1
        if count > 1, let additionalGate { await additionalGate.suspend() }
        try Task.checkCancellation()
        if let failure { throw failure }
        return [MyStudy(id: "12", title: "표시 스터디", category: .software, studyKind: .study,
                        startAt: nil, endAt: nil, relation: .ongoing, participantStatus: .active,
                        participantRole: .member, discordChannelUrl: nil, driveUrl: nil,
                        attendanceRate: nil, meetings: [])]
    }
}

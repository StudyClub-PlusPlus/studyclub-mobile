import Combine
import XCTest
@testable import studyclub

@MainActor
final class SettingAccountViewModelTests: XCTestCase {
    func testFlagOffDoesNotRestoreOrLogout() {
        let repository = AuthRepositoryDouble()
        let viewModel = SettingAccountViewModel(repository: repository, isFeatureEnabled: false)
        XCTAssertEqual(viewModel.state, .hidden)
        XCTAssertNil(viewModel.nickname)
        XCTAssertEqual(viewModel.presentation, .none)
        XCTAssertEqual(repository.counts().restore, 0)
        XCTAssertEqual(repository.counts().logout, 0)
        XCTAssertFalse(viewModel.allows(.login))
    }

    func testRestoreMemberHidesNicknameUntilTheCheckFinishes() async {
        let (viewModel, repository) = await startedViewModel()
        XCTAssertEqual(viewModel.state, .checking)
        XCTAssertNil(viewModel.nickname)
        repository.finishRestore(.success(Member(nickname: "민수")))
        await waitUntil(viewModel.state == .member(nickname: "민수"))
        XCTAssertEqual(viewModel.nickname, "민수")
        XCTAssertEqual(viewModel.presentation, .none)
    }

    func testConfirmedInvalidSessionStaysGuestWithoutLogin() async {
        let (viewModel, repository) = await startedViewModel()
        repository.finishRestore(.success(nil))
        await waitUntil(viewModel.state == .guest)
        XCTAssertEqual(viewModel.presentation, .none)
        XCTAssertNil(viewModel.loginViewModel)
        let (invalid, invalidRepository) = await startedViewModel()
        invalidRepository.finishRestore(.failure(AuthError.authenticationInvalid))
        await waitUntil(invalid.state == .guest)
        XCTAssertEqual(invalid.presentation, .none)
    }

    func testTransientRestoreFailureKeepsRecheckAndNoNickname() async {
        let (viewModel, repository) = await startedViewModel()
        repository.finishRestore(.failure(AuthError.connectionFailure))
        await waitUntil(viewModel.state == .connectionFailure)
        XCTAssertNil(viewModel.nickname)
        XCTAssertTrue(viewModel.allows(.recheck))
        viewModel.recheckSession()
        await waitUntil(repository.counts().restore == 2)
        repository.finishRestore(.failure(AuthError.unavailable))
        await waitUntil(viewModel.state == .connectionFailure)
        viewModel.recheckSession()
        await waitUntil(repository.counts().restore == 3)
        repository.finishRestore(.success(Member(nickname: "민수")))
        await waitUntil(viewModel.state == .member(nickname: "민수"))
    }

    func testInvalidateDropsLateRestoreMember() async throws {
        let (viewModel, repository) = await startedViewModel()
        try await viewModel.invalidate()
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 1)
        XCTAssertEqual(viewModel.presentation, .none)
        let leaked = expectation(description: "late member")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.state, .checking)
        withExtendedLifetime(subscription) {}
    }

    func testTurningFlagOffThenOnIgnoresThePreviousRestore() async {
        let (viewModel, repository) = await startedViewModel()
        viewModel.updateFeatureVisibility(isEnabled: false)
        XCTAssertEqual(viewModel.state, .hidden)
        viewModel.updateFeatureVisibility(isEnabled: true)
        await waitUntil(repository.counts().restore == 2)
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        repository.finishRestore(.success(nil))
        await waitUntil(viewModel.state == .guest)
        XCTAssertNil(viewModel.nickname)
        XCTAssertEqual(repository.counts().logout, 0)
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 1)
    }

    func testGoogleMemberReturnsToSettings() async {
        let (viewModel, repository) = await openLogin()
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        repository.finishSignIn(.success(.member(Member(nickname: "민수"))))
        await waitUntil(viewModel.state == .member(nickname: "민수"))
        XCTAssertEqual(viewModel.presentation, .none)
        XCTAssertNil(viewModel.loginViewModel)
    }

    func testSignupRequiredUsesSuggestedOrDefaultNickname() async {
        let (viewModel, repository) = await openLogin()
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        repository.finishSignIn(.success(.signupRequired(suggestedNickname: "제안")))
        await waitUntil(viewModel.presentation == .signup)
        XCTAssertEqual(viewModel.onboardingViewModel?.input.nickname, "제안")

        let (defaulted, defaultRepository) = await openLogin()
        defaulted.loginViewModel?.requestSignIn()
        defaulted.signInWithGoogle()
        await waitUntil(defaultRepository.counts().signIn == 1)
        defaultRepository.finishSignIn(.success(.signupRequired(suggestedNickname: nil)))
        await waitUntil(defaulted.presentation == .signup)
        XCTAssertEqual(defaulted.onboardingViewModel?.input.nickname, "스터디친구")
    }

    func testMissingConfigurationDoesNotBecomeAMember() async {
        let (viewModel, repository) = await openLogin()
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        repository.finishSignIn(.failure(AuthError.configurationMissing))
        await waitUntil(viewModel.loginViewModel?.state == .unavailable)
        viewModel.signInWithGoogle()
        XCTAssertEqual(repository.counts().signIn, 1)
        XCTAssertEqual(viewModel.state, .guest)
    }

    func testCancelDropsLateSignInSuccess() async {
        let (viewModel, repository) = await openLogin()
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        viewModel.loginViewModel?.requestCancellation()
        viewModel.cancelSignIn()
        await waitUntil(repository.counts().discard >= 1)
        let leaked = expectation(description: "late sign-in member")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        repository.finishSignIn(.success(.member(Member(nickname: "늦은회원"))))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.state, .guest)
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelled)
        withExtendedLifetime(subscription) {}
    }

    func testTermsAndPrivacyOpenLiveSitePagesAndAllowConsent() {
        let documents = AuthDocuments()
        XCTAssertTrue(documents.allowsConsentAndSubmit)
        XCTAssertEqual(documents.url(for: .terms)?.path(), "/ko/terms")
        XCTAssertEqual(documents.url(for: .privacy)?.path(), "/ko/privacy")
        XCTAssertEqual(documents.url(for: .terms)?.host(), AuthDocuments.webRoot.host())
        XCTAssertNil(documents.url(for: .marketing))
    }

    func testUnconfirmedTermsBlockConsentAndSubmitWhileFlagIsOn() async throws {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: false)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        XCTAssertFalse(onboarding.allowsConsentAndSubmit)
        onboarding.updateConsents(age: true, terms: true, privacy: true, marketing: true)
        XCTAssertFalse(onboarding.input.age14Confirmed)
        XCTAssertFalse(onboarding.input.termsOfServiceAgreed)
        XCTAssertNil(onboarding.submit())
        viewModel.submitSignup(OnboardingViewModel.Input(nickname: "제안", timeZone: "Etc/UTC", age14Confirmed: true, termsOfServiceAgreed: true, privacyPolicyAgreed: true))
        XCTAssertEqual(repository.counts().signup, 0)
        XCTAssertEqual(viewModel.state, .guest)
    }

    func testConfirmedTermsSubmitOnceAndRejectionKeepsInput() async throws {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        onboarding.updateConsents(age: true, terms: true, privacy: true, marketing: false)
        let input = try XCTUnwrap(onboarding.submit())
        viewModel.submitSignup(input)
        await waitUntil(repository.counts().signup == 1)
        let registration = try XCTUnwrap(repository.counts().registrations.first)
        XCTAssertEqual(registration.nickname, input.nickname)
        XCTAssertEqual(registration.timeZone, input.timeZone)
        XCTAssertTrue(registration.age14Confirmed)
        XCTAssertTrue(registration.termsOfServiceAgreed)
        XCTAssertTrue(registration.privacyPolicyAgreed)
        XCTAssertFalse(registration.marketingAgreed)
        repository.finishSignup(.failure(AuthError.signupRejected(.nicknameTaken)))
        await waitUntil(onboarding.state == .editing)
        XCTAssertEqual(onboarding.input.nickname, input.nickname)
        XCTAssertEqual(onboarding.nicknameError, "이미 사용 중인 닉네임이에요.")
        XCTAssertEqual(repository.counts().signup, 1)
    }

    func testUnknownSignupCannotBeSubmittedAgain() async throws {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        onboarding.updateConsents(age: true, terms: true, privacy: true, marketing: false)
        viewModel.submitSignup(try XCTUnwrap(onboarding.submit()))
        await waitUntil(repository.counts().signup == 1)
        repository.finishSignup(.failure(AuthError.signupStatusUnknown))
        await waitUntil(onboarding.state == .unknownStatus)
        XCTAssertNil(onboarding.submit())
        viewModel.submitSignup(onboarding.input)
        XCTAssertEqual(repository.counts().signup, 1)

        XCTAssertTrue(onboarding.beginStatusCheck())
        viewModel.recheckSignup()
        await waitUntil(repository.counts().recheck == 1)
        repository.finishRecheck(.failure(AuthError.connectionFailure))
        await waitUntil(onboarding.state == .unknownStatus)
        XCTAssertEqual(repository.counts().signup, 1)
    }

    func testRecheckCanFinishOrReturnToEditing() async throws {
        let (finished, finishedRepository) = try await openUnknownSignup()
        let finishedOnboarding = try XCTUnwrap(finished.onboardingViewModel)
        XCTAssertTrue(finishedOnboarding.beginStatusCheck())
        finished.recheckSignup()
        await waitUntil(finishedRepository.counts().recheck == 1)
        finishedRepository.finishRecheck(.success(.member(Member(nickname: "민수"))))
        await waitUntil(finished.state == .member(nickname: "민수"))
        XCTAssertEqual(finished.presentation, .none)

        let (editing, editingRepository) = try await openUnknownSignup()
        let editingOnboarding = try XCTUnwrap(editing.onboardingViewModel)
        let nickname = editingOnboarding.input.nickname
        XCTAssertTrue(editingOnboarding.beginStatusCheck())
        editing.recheckSignup()
        await waitUntil(editingRepository.counts().recheck == 1)
        editingRepository.finishRecheck(.success(.signupRequired(suggestedNickname: "다른이름")))
        await waitUntil(editingOnboarding.state == .editing)
        XCTAssertEqual(editingOnboarding.input.nickname, nickname)
        XCTAssertEqual(editing.presentation, .signup)
    }

    func testAbandonSignupDiscardsPendingAuth() async {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        viewModel.onboardingViewModel?.beginClose()
        viewModel.abandonSignup()
        await waitUntil(repository.counts().discard >= 1)
        await waitUntil(viewModel.presentation == .none)
        XCTAssertEqual(viewModel.state, .guest)
        XCTAssertNil(viewModel.onboardingViewModel)
    }

    func testCancellationStaysPendingUntilDiscardSucceeds() async {
        let (viewModel, repository) = await openLogin()
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        repository.suspendDiscard = true
        XCTAssertEqual(viewModel.loginViewModel?.requestCancellation(), true)
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelling)
        XCTAssertFalse(viewModel.loginViewModel?.canSignIn ?? true)
        viewModel.cancelSignIn()
        await waitUntil(repository.counts().discard == 1)
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelling)
        XCTAssertEqual(viewModel.presentation, .login)
        repository.finishDiscard(.failure(AuthError.unavailable))
        await waitUntil(viewModel.loginViewModel?.state == .cleanupFailed)
        XCTAssertFalse(viewModel.loginViewModel?.canSignIn ?? true)
        XCTAssertEqual(repository.counts().signIn, 1)
        viewModel.signInWithGoogle()
        XCTAssertEqual(repository.counts().signIn, 1)
        viewModel.retryLoginCleanup()
        await waitUntil(repository.counts().discard == 2)
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelling)
        repository.finishDiscard(.success(()))
        await waitUntil(viewModel.loginViewModel?.state == .cancelled)
        XCTAssertEqual(viewModel.presentation, .login)
        XCTAssertEqual(repository.counts().signIn, 1)
        let leaked = expectation(description: "late member after cancel")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        repository.finishSignIn(.success(.member(Member(nickname: "늦은회원"))))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelled)
        withExtendedLifetime(subscription) {}
    }

    func testDiscardFailureDoesNotCloseLogin() async {
        let (viewModel, repository) = await openLogin()
        repository.suspendDiscard = true
        viewModel.closeLogin()
        XCTAssertEqual(viewModel.loginViewModel?.state, .cancelling)
        XCTAssertEqual(viewModel.presentation, .login)
        await waitUntil(repository.counts().discard == 1)
        repository.finishDiscard(.failure(AuthError.unavailable))
        await waitUntil(viewModel.loginViewModel?.state == .cleanupFailed)
        XCTAssertEqual(viewModel.presentation, .login)
        XCTAssertFalse(viewModel.loginViewModel?.canSignIn ?? true)
        viewModel.retryLoginCleanup()
        await waitUntil(repository.counts().discard == 2)
        repository.finishDiscard(.success(()))
        await waitUntil(viewModel.presentation == .none)
        XCTAssertEqual(viewModel.state, .guest)
    }

    func testUncertainCloseKeepsInputUntilDiscardSucceeds() async throws {
        let (viewModel, repository) = try await openUnknownSignup()
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        let nickname = onboarding.input.nickname
        repository.suspendDiscard = true
        onboarding.beginClose()
        XCTAssertEqual(onboarding.state, .cancelling)
        XCTAssertEqual(onboarding.input.nickname, nickname)
        viewModel.abandonSignup()
        await waitUntil(repository.counts().discard == 1)
        XCTAssertEqual(viewModel.presentation, .signup)
        XCTAssertEqual(onboarding.state, .cancelling)
        XCTAssertEqual(onboarding.input.nickname, nickname)
        repository.finishDiscard(.failure(AuthError.unavailable))
        await waitUntil(onboarding.state == .cleanupFailed)
        XCTAssertEqual(viewModel.presentation, .signup)
        XCTAssertEqual(onboarding.input.nickname, nickname)
        XCTAssertNil(onboarding.submit())
        XCTAssertFalse(onboarding.beginStatusCheck())
        viewModel.startLogin()
        XCTAssertEqual(viewModel.presentation, .signup)
        viewModel.retryAbandonSignup()
        await waitUntil(repository.counts().discard == 2)
        XCTAssertEqual(onboarding.state, .cancelling)
        repository.finishDiscard(.success(()))
        await waitUntil(viewModel.presentation == .none)
        XCTAssertEqual(viewModel.state, .guest)
        XCTAssertNil(viewModel.onboardingViewModel)
    }

    func testDiscardFailureDoesNotAbandonAsGuest() async throws {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        let nickname = onboarding.input.nickname
        onboarding.beginClose()
        repository.failNextDiscard(AuthError.unavailable)
        viewModel.abandonSignup()
        await waitUntil(onboarding.state == .cleanupFailed)
        XCTAssertEqual(onboarding.input.nickname, nickname)
        XCTAssertEqual(viewModel.presentation, .signup)
        XCTAssertNotNil(viewModel.onboardingViewModel)
        XCTAssertEqual(viewModel.state, .guest)
    }

    func testFlagOffDiscardFailureRetriesCleanupWithoutRestore() async {
        let (viewModel, repository) = await startedViewModel()
        repository.failNextDiscard(AuthError.unavailable)
        viewModel.updateFeatureVisibility(isEnabled: false)
        await waitUntil(viewModel.cleanupBlocked)
        XCTAssertEqual(viewModel.state, .hidden)
        XCTAssertNil(viewModel.nickname)
        XCTAssertFalse(viewModel.allows(.login))
        XCTAssertFalse(viewModel.allows(.recheck))
        XCTAssertEqual(repository.counts().restore, 1)
        repository.failNextDiscard(nil)
        viewModel.retryHiddenCleanup()
        await waitUntil(!viewModel.cleanupBlocked)
        XCTAssertEqual(viewModel.state, .hidden)
        XCTAssertEqual(repository.counts().restore, 1)
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 2)
        let leaked = expectation(description: "late member while hidden")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.state, .hidden)
        XCTAssertFalse(viewModel.cleanupBlocked)
        withExtendedLifetime(subscription) {}
    }

    func testSignupDiscardFailureRetriesCleanupWithoutRestoreOrLogin() async throws {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        let restores = repository.counts().restore
        onboarding.beginClose()
        repository.failNextDiscard(AuthError.unavailable)
        viewModel.abandonSignup()
        await waitUntil(onboarding.state == .cleanupFailed)
        repository.failNextDiscard(nil)
        viewModel.retryAbandonSignup()
        await waitUntil(viewModel.presentation == .none)
        XCTAssertEqual(viewModel.state, .guest)
        XCTAssertEqual(repository.counts().restore, restores)
        XCTAssertEqual(repository.counts().signIn, 1)
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 2)
    }

    func testInvalidateDiscardFailureStaysRetryable() async {
        let (viewModel, repository) = await startedViewModel()
        repository.failNextDiscard(AuthError.unavailable)
        do {
            try await viewModel.invalidate()
            XCTFail("discard failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .unavailable)
        }
        XCTAssertEqual(viewModel.state, .connectionFailure)
        XCTAssertEqual(viewModel.presentation, .none)
        let leaked = expectation(description: "late member after failed invalidate")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.state, .connectionFailure)
        withExtendedLifetime(subscription) {}
    }

    func testLogoutFailureStaysMemberUntilRetrySucceeds() async {
        let (viewModel, repository) = await memberViewModel(nickname: "민수")
        viewModel.logout()
        viewModel.logout()
        await waitUntil(repository.counts().logout == 1)
        repository.finishLogout(.failure(AuthError.logoutFailed))
        await waitUntil(viewModel.state == .logoutFailure(nickname: "민수"))
        XCTAssertEqual(viewModel.nickname, "민수")
        viewModel.logout()
        await waitUntil(repository.counts().logout == 2)
        repository.finishLogout(.success(()))
        await waitUntil(viewModel.state == .guest)
        XCTAssertNil(viewModel.nickname)
    }

    func testReleasingTheOwnerDuringRestoreCancelsWithoutInvalidate() async {
        let repository = AuthRepositoryDouble()
        let started = expectation(description: "restore started")
        repository.onRestore = { started.fulfill() }
        var viewModel: SettingAccountViewModel? = SettingAccountViewModel(
            repository: repository,
            isFeatureEnabled: true
        )
        weak var released = viewModel
        await fulfillment(of: [started], timeout: 2)
        viewModel = nil
        await waitUntil(released == nil && repository.counts().cancel >= 1)
        XCTAssertNil(released)
        XCTAssertGreaterThanOrEqual(repository.counts().cancel, 1)
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        XCTAssertNil(released)
    }

    #if DEBUG
    func testDevelopmentSettingsAuthToggleDropsTheSuspendedRestore() async {
        let previous = UserDefaults.standard.dictionary(forKey: flagDefaultsKey)
        defer { restoreFlagDefaults(previous) }
        var account: SettingAccountViewModel?
        let settings = DevelopmentSettingsViewModel {
            account?.updateFeatureVisibility(
                isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
            )
        }
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: true)
        let repository = AuthRepositoryDouble()
        let started = expectation(description: "settings restore")
        repository.onRestore = { started.fulfill() }
        account = SettingAccountViewModel(repository: repository, isFeatureEnabled: true)
        await fulfillment(of: [started], timeout: 2)
        repository.onRestore = nil
        settings.setFlag(id: FeatureFlag.studyDesignSystem.definition.id, isEnabled: true)
        XCTAssertEqual(account?.state, .checking)
        XCTAssertEqual(repository.counts().discard, 0)
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: false)
        await waitUntil(account?.state == .hidden)
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: true)
        await waitUntil(repository.counts().restore == 2)
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        repository.finishRestore(.success(nil))
        await waitUntil(account?.state == .guest)
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 1)
        XCTAssertEqual(repository.counts().logout, 0)
    }

    func testStaleRootInvalidateFailureAfterFlagOffStaysHidden() async throws {
        let previous = UserDefaults.standard.dictionary(forKey: flagDefaultsKey)
        defer { restoreFlagDefaults(previous) }
        var account: SettingAccountViewModel?
        let settings = DevelopmentSettingsViewModel {
            account?.updateFeatureVisibility(
                isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
            )
        }
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: true)
        let repository = AuthRepositoryDouble()
        let started = expectation(description: "restore before stale invalidate")
        repository.onRestore = { started.fulfill() }
        account = SettingAccountViewModel(repository: repository, isFeatureEnabled: true)
        await fulfillment(of: [started], timeout: 2)
        repository.onRestore = nil
        repository.finishRestore(.success(Member(nickname: "민수")))
        await waitUntil(account?.state == .member(nickname: "민수"))
        let restores = repository.counts().restore

        repository.suspendDiscard = true
        let invalidation = Task { try await account?.invalidate() }
        await waitUntil(repository.discardWaiterCount() == 1)
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: false)
        await waitUntil(repository.discardWaiterCount() == 2)
        XCTAssertEqual(account?.state, .hidden)
        XCTAssertNil(account?.nickname)

        repository.finishDiscard(at: 1, .failure(AuthError.unavailable))
        await waitUntil(account?.cleanupBlocked == true)
        XCTAssertEqual(account?.state, .hidden)
        XCTAssertNil(account?.nickname)

        let leaked = expectation(description: "stale invalidate reveals an account row")
        leaked.isInverted = true
        let subscription = account?.statePublisher.sink { state in
            switch state {
            case .hidden:
                break
            case .guest, .checking, .connectionFailure, .member, .logoutFailure:
                leaked.fulfill()
            }
        }
        repository.finishDiscard(at: 0, .failure(AuthError.unavailable))
        do {
            try await invalidation.value
            XCTFail("stale discard failure")
        } catch {
            XCTAssertEqual(error as? AuthError, .unavailable)
        }
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(account?.state, .hidden)
        XCTAssertNil(account?.nickname)
        XCTAssertEqual(account?.presentation, Optional(SettingAccountViewModel.Presentation.none))
        XCTAssertTrue(account?.cleanupBlocked == true)
        XCTAssertEqual(repository.counts().restore, restores)
        XCTAssertEqual(repository.counts().discard, 2)
        withExtendedLifetime(subscription) {}
    }

    func testResetFlagsTurnsAuthOffAndDropsTheSuspendedRestore() async {
        let previous = UserDefaults.standard.dictionary(forKey: flagDefaultsKey)
        defer { restoreFlagDefaults(previous) }
        var account: SettingAccountViewModel?
        let settings = DevelopmentSettingsViewModel {
            account?.updateFeatureVisibility(
                isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
            )
        }
        settings.setFlag(id: FeatureFlag.googleLogin.definition.id, isEnabled: true)
        let repository = AuthRepositoryDouble()
        let started = expectation(description: "reset restore")
        repository.onRestore = { started.fulfill() }
        account = SettingAccountViewModel(repository: repository, isFeatureEnabled: true)
        await fulfillment(of: [started], timeout: 2)
        let leaked = expectation(description: "reset late member")
        leaked.isInverted = true
        let subscription = account?.statePublisher.sink { state in
            if case .member = state { leaked.fulfill() }
        }
        settings.resetFlagsToDefaults()
        await waitUntil(account?.state == .hidden)
        repository.finishRestore(.success(Member(nickname: "늦은회원")))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(account?.state, .hidden)
        XCTAssertGreaterThanOrEqual(repository.counts().discard, 1)
        withExtendedLifetime(subscription) {}
    }
    #endif

    func testLateLogoutSuccessAfterFlagOffDoesNotClearHiddenState() async {
        let (viewModel, repository) = await memberViewModel(nickname: "민수")
        viewModel.logout()
        await waitUntil(repository.counts().logout == 1)
        viewModel.updateFeatureVisibility(isEnabled: false)
        let leaked = expectation(description: "late guest")
        leaked.isInverted = true
        let subscription = viewModel.statePublisher.sink { state in
            if state == .guest { leaked.fulfill() }
        }
        repository.finishLogout(.success(()))
        await fulfillment(of: [leaked], timeout: 0.3)
        XCTAssertEqual(viewModel.state, .hidden)
        XCTAssertEqual(viewModel.presentation, .none)
        XCTAssertEqual(repository.counts().logout, 1)
        withExtendedLifetime(subscription) {}
    }

    private let flagDefaultsKey = "development.featureFlags"

    private func restoreFlagDefaults(_ previous: [String: Any]?) {
        if let previous {
            UserDefaults.standard.set(previous, forKey: flagDefaultsKey)
        } else {
            UserDefaults.standard.removeObject(forKey: flagDefaultsKey)
        }
    }

    private func startedViewModel(allowsConsent: Bool = false) async -> (SettingAccountViewModel, AuthRepositoryDouble) {
        let repository = AuthRepositoryDouble()
        let started = expectation(description: "restore")
        repository.onRestore = { started.fulfill() }
        let viewModel = SettingAccountViewModel(
            repository: repository,
            isFeatureEnabled: true,
            allowsConsentAndSubmit: allowsConsent
        )
        await fulfillment(of: [started], timeout: 2)
        repository.onRestore = nil
        return (viewModel, repository)
    }

    private func openLogin(allowsConsent: Bool = false) async -> (SettingAccountViewModel, AuthRepositoryDouble) {
        let (viewModel, repository) = await startedViewModel(allowsConsent: allowsConsent)
        repository.finishRestore(.success(nil))
        await waitUntil(viewModel.state == .guest)
        viewModel.startLogin()
        XCTAssertEqual(viewModel.presentation, .login)
        viewModel.startLogin()
        XCTAssertNotNil(viewModel.loginViewModel)
        return (viewModel, repository)
    }

    private func openSignup(suggested: String?, allowsConsent: Bool) async -> (SettingAccountViewModel, AuthRepositoryDouble) {
        let (viewModel, repository) = await openLogin(allowsConsent: allowsConsent)
        viewModel.loginViewModel?.requestSignIn()
        viewModel.signInWithGoogle()
        await waitUntil(repository.counts().signIn == 1)
        repository.finishSignIn(.success(.signupRequired(suggestedNickname: suggested)))
        await waitUntil(viewModel.presentation == .signup)
        return (viewModel, repository)
    }

    private func openUnknownSignup() async throws -> (SettingAccountViewModel, AuthRepositoryDouble) {
        let (viewModel, repository) = await openSignup(suggested: "제안", allowsConsent: true)
        let onboarding = try XCTUnwrap(viewModel.onboardingViewModel)
        onboarding.updateConsents(age: true, terms: true, privacy: true, marketing: false)
        viewModel.submitSignup(try XCTUnwrap(onboarding.submit()))
        await waitUntil(repository.counts().signup == 1)
        repository.finishSignup(.failure(AuthError.signupStatusUnknown))
        await waitUntil(onboarding.state == .unknownStatus)
        return (viewModel, repository)
    }

    private func memberViewModel(nickname: String) async -> (SettingAccountViewModel, AuthRepositoryDouble) {
        let (viewModel, repository) = await startedViewModel()
        repository.finishRestore(.success(Member(nickname: nickname)))
        await waitUntil(viewModel.state == .member(nickname: nickname))
        return (viewModel, repository)
    }

    private func waitUntil(_ predicate: @escaping @autoclosure () -> Bool, timeout: TimeInterval = 2) async {
        if predicate() { return }
        let done = expectation(description: "condition")
        let watcher = Task { @MainActor in
            for _ in 0..<100 {
                if predicate() {
                    done.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 10_000_000)
            }
        }
        await fulfillment(of: [done], timeout: timeout)
        watcher.cancel()
    }
}

private final class AuthRepositoryDouble: AuthRepository, @unchecked Sendable {
    struct Counts: Equatable {
        var restore = 0
        var signIn = 0
        var signup = 0
        var recheck = 0
        var discard = 0
        var logout = 0
        var cancel = 0
        var registrations: [MemberRegistration] = []
    }

    private let lock = NSLock()
    private var restoreCount = 0
    private var signInCount = 0
    private var signupCount = 0
    private var recheckCount = 0
    private var discardCount = 0
    private var logoutCount = 0
    private var cancelCount = 0
    private var discardFailure: Error?
    private var discardWaiters: [CheckedContinuation<Void, Error>] = []
    private var registrations: [MemberRegistration] = []
    private var restoreWaiters: [CheckedContinuation<Member?, Error>] = []
    private var signInWaiters: [CheckedContinuation<SignInOutcome, Error>] = []
    private var signupWaiters: [CheckedContinuation<Member, Error>] = []
    private var recheckWaiters: [CheckedContinuation<SignInOutcome, Error>] = []
    private var logoutWaiters: [CheckedContinuation<Void, Error>] = []
    var onRestore: (@Sendable () -> Void)?
    var suspendDiscard = false

    func counts() -> Counts {
        lock.lock()
        defer { lock.unlock() }
        return Counts(
            restore: restoreCount, signIn: signInCount, signup: signupCount, recheck: recheckCount,
            discard: discardCount, logout: logoutCount, cancel: cancelCount, registrations: registrations
        )
    }

    func restoreSession() async throws -> Member? {
        let handler = locked { () -> (@Sendable () -> Void)? in
            restoreCount += 1
            return onRestore
        }
        handler?()
        return try await suspend { restoreWaiters.append($0) }
    }

    func signInWithGoogle() async throws -> SignInOutcome {
        locked { signInCount += 1 }
        return try await suspend { signInWaiters.append($0) }
    }

    func completeSignup(_ registration: MemberRegistration) async throws -> Member {
        locked { signupCount += 1; registrations.append(registration) }
        return try await suspend { signupWaiters.append($0) }
    }

    func checkSignupCompletion() async throws -> SignInOutcome {
        locked { recheckCount += 1 }
        return try await suspend { recheckWaiters.append($0) }
    }

    func discardPendingSignup() async throws {
        let plan = locked { () -> (Error?, Bool) in
            discardCount += 1
            return (discardFailure, suspendDiscard)
        }
        if plan.1 {
            try await suspend { discardWaiters.append($0) }
        }
        if let failure = plan.0 { throw failure }
    }

    func failNextDiscard(_ error: Error?) {
        locked { discardFailure = error }
    }

    func logout() async throws {
        locked { logoutCount += 1 }
        try await suspend { logoutWaiters.append($0) }
    }

    private func suspend<T>(_ store: (CheckedContinuation<T, Error>) -> Void) async throws -> T {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                locked { store(continuation) }
            }
        } onCancel: { [weak self] in
            self?.noteCancel()
        }
    }

    private func noteCancel() {
        lock.lock()
        cancelCount += 1
        lock.unlock()
    }

    func finishRestore(_ result: Result<Member?, Error>) { resume(&restoreWaiters, result) }
    func finishSignIn(_ result: Result<SignInOutcome, Error>) { resume(&signInWaiters, result) }
    func finishSignup(_ result: Result<Member, Error>) { resume(&signupWaiters, result) }
    func finishRecheck(_ result: Result<SignInOutcome, Error>) { resume(&recheckWaiters, result) }
    func finishLogout(_ result: Result<Void, Error>) { resume(&logoutWaiters, result) }
    func finishDiscard(_ result: Result<Void, Error>) { resume(&discardWaiters, result) }

    func discardWaiterCount() -> Int { locked { discardWaiters.count } }

    func finishDiscard(at index: Int, _ result: Result<Void, Error>) {
        lock.lock()
        let continuation = discardWaiters.remove(at: index)
        lock.unlock()
        continuation.resume(with: result)
    }

    private func resume<T>(_ waiters: inout [CheckedContinuation<T, Error>], _ result: Result<T, Error>) {
        lock.lock()
        let continuation = waiters.removeFirst()
        lock.unlock()
        continuation.resume(with: result)
    }

    private func locked(_ body: () -> Void) {
        lock.lock()
        body()
        lock.unlock()
    }

    private func locked<T>(_ body: () -> T) -> T {
        lock.lock()
        let value = body()
        lock.unlock()
        return value
    }
}

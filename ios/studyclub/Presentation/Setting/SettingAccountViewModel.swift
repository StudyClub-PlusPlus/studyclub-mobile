import Combine
import Foundation

/// Owns the root's shared auth repository and the login/onboarding display models.
/// View controllers receive those display models and callbacks, never the repository.
@MainActor
final class SettingAccountViewModel {
    enum State: Equatable {
        case hidden, guest, checking, connectionFailure
        case member(nickname: String)
        case logoutFailure(nickname: String)
    }

    enum Action: Equatable { case login, recheck, logout }

    enum Presentation: Equatable { case none, login, signup }

    private let repository: any AuthRepository
    private let allowsConsentAndSubmit: Bool
    private let isMock: Bool
    private let stateSubject: CurrentValueSubject<State, Never>
    private let presentationSubject: CurrentValueSubject<Presentation, Never>
    private var accountTask: Task<Void, Never>?
    private var sharedRecheckRequested = false
    /// Identity of the task that may still change account state.
    private var operationID: UUID?
    /// Root invalidation may publish only while this value is still current.
    private var invalidateToken: UUID?
    /// The last `discardPendingSignup()` failed, so retry repeats that cleanup.
    private var discardFailed = false
    /// Login cleanup stays on the sheet until discard succeeds. Close dismisses only after that.
    private enum LoginCleanup { case cancel, close }
    private var loginCleanup: LoginCleanup?
    private let cleanupBlockedSubject: CurrentValueSubject<Bool, Never>
    private(set) var cleanupBlocked: Bool

    private(set) var state: State
    private(set) var isFeatureEnabled: Bool
    private(set) var presentation: Presentation
    private(set) var loginViewModel: LoginViewModel?
    private(set) var onboardingViewModel: OnboardingViewModel?
    var statePublisher: AnyPublisher<State, Never> { stateSubject.eraseToAnyPublisher() }
    var presentationPublisher: AnyPublisher<Presentation, Never> { presentationSubject.eraseToAnyPublisher() }
    var cleanupBlockedPublisher: AnyPublisher<Bool, Never> { cleanupBlockedSubject.eraseToAnyPublisher() }

    var nickname: String? {
        switch state {
        case let .member(nickname), let .logoutFailure(nickname): return nickname
        default: return nil
        }
    }

    convenience init() {
        let repositories = RepositoryFactory.makeMemberRepositories()
        self.init(
            repository: repositories.auth,
            isFeatureEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition),
            isMock: repositories.isMock
        )
    }

    init(repository: any AuthRepository, isFeatureEnabled: Bool, allowsConsentAndSubmit: Bool = AuthDocuments().allowsConsentAndSubmit,
         isMock: Bool = false) {
        self.repository = repository
        #if DEBUG
        self.isMock = isMock
        #else
        self.isMock = false
        #endif
        self.allowsConsentAndSubmit = allowsConsentAndSubmit || self.isMock
        self.isFeatureEnabled = isFeatureEnabled
        let initial: State = isFeatureEnabled ? .checking : .hidden
        state = initial
        presentation = .none
        cleanupBlocked = false
        stateSubject = CurrentValueSubject(initial)
        presentationSubject = CurrentValueSubject(.none)
        cleanupBlockedSubject = CurrentValueSubject(false)
        if isFeatureEnabled {
            beginRestore(droppingPendingWork: false)
        }
    }

    deinit { accountTask?.cancel() }

    func updateFeatureVisibility(isEnabled: Bool) {
        guard isEnabled != isFeatureEnabled else { return }
        isFeatureEnabled = isEnabled
        if isEnabled {
            setCleanupBlocked(false)
            beginRestore(droppingPendingWork: true)
        } else {
            publish(.hidden)
            clearPresentedFlow()
            beginOffCleanup()
        }
    }

    func allows(_ action: Action) -> Bool {
        guard isFeatureEnabled else { return false }
        switch (state, action) {
        case (.guest, .login), (.connectionFailure, .recheck),
             (.member, .logout), (.logoutFailure, .logout): return true
        default: return false
        }
    }

    func invalidate() async throws {
        sharedRecheckRequested = false
        accountTask?.cancel()
        accountTask = nil
        operationID = nil
        let token = UUID()
        invalidateToken = token
        do {
            try await repository.discardPendingSignup()
        } catch {
            // A newer account operation, or a flag that is now off, owns the screen.
            // Failure still throws so root replacement does not treat this call as success.
            guard invalidateToken == token, isFeatureEnabled else { throw error }
            discardFailed = true
            clearPresentedFlow()
            publish(.connectionFailure)
            throw error
        }
        guard invalidateToken == token, isFeatureEnabled else { return }
        discardFailed = false
        clearPresentedFlow()
    }

    func startLogin() {
        guard allows(.login), presentation == .none, !isBusy else { return }
        loginViewModel = LoginViewModel(isMock: isMock)
        onboardingViewModel = nil
        publishPresentation(.login)
    }

    func signInWithGoogle() {
        signIn { try await $0.signInWithGoogle() }
    }

    func signInWithApple() {
        signIn { try await $0.signInWithApple() }
    }

    private func signIn(_ run: @escaping @MainActor (any AuthRepository) async throws -> SignInOutcome) {
        guard isFeatureEnabled, presentation == .login, loginViewModel?.state == .signingIn, !isBusy else { return }
        begin { [weak self] operation, repository in
            do {
                let outcome = try await run(repository)
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.apply(outcome)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.applySignIn(error)
            }
        }
    }

    func cancelSignIn() {
        guard presentation == .login, loginViewModel?.state == .cancelling else { return }
        loginCleanup = .cancel
        beginLoginCleanup()
    }

    func retryLoginCleanup() {
        guard presentation == .login, loginViewModel?.requestCleanupRetry() == true else { return }
        beginLoginCleanup()
    }

    func closeLogin() {
        guard presentation == .login else { return }
        loginCleanup = .close
        if loginViewModel?.state == .cancelling, isBusy { return }
        loginViewModel?.update(state: .cancelling)
        beginLoginCleanup()
    }

    func submitSignup(_ input: OnboardingViewModel.Input) {
        guard isFeatureEnabled, allowsConsentAndSubmit, presentation == .signup,
              onboardingViewModel?.state == .submitting, !isBusy else { return }
        let registration = MemberRegistration(
            nickname: input.nickname,
            timeZone: input.timeZone,
            age14Confirmed: input.age14Confirmed,
            termsOfServiceAgreed: input.termsOfServiceAgreed,
            privacyPolicyAgreed: input.privacyPolicyAgreed,
            marketingAgreed: input.marketingAgreed
        )
        begin { [weak self] operation, repository in
            do {
                let member = try await repository.completeSignup(registration)
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.finishMember(member)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.applySignup(error)
            }
        }
    }

    func recheckSignup() {
        guard isFeatureEnabled, presentation == .signup, onboardingViewModel?.state == .checkingStatus, !isBusy else { return }
        begin { [weak self] operation, repository in
            do {
                let outcome = try await repository.checkSignupCompletion()
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                switch outcome {
                case let .member(member):
                    self.finishMember(member)
                case .signupRequired:
                    self.onboardingViewModel?.showEditing(message: "가입이 아직 완료되지 않았어요. 내용을 확인하고 다시 제출해 주세요.")
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                if case .featureUnavailable? = error as? AuthError {
                    self.applyFeatureOff()
                    return
                }
                self.onboardingViewModel?.showUnknownStatus(
                    message: "가입 결과를 확인하지 못했어요. 다시 제출하지 말고 완료 여부를 확인해 주세요."
                )
            }
        }
    }

    func abandonSignup() {
        guard presentation == .signup else { return }
        onboardingViewModel?.beginClose()
        beginAbandonSignup()
    }

    func retryAbandonSignup() {
        guard presentation == .signup, onboardingViewModel?.requestCleanupRetry() == true else { return }
        beginAbandonSignup()
    }

    private func beginAbandonSignup() {
        begin { [weak self] operation, repository in
            do {
                try await repository.discardPendingSignup()
            } catch {
                guard let self, self.isCurrent(operation) else { return }
                self.discardFailed = true
                self.onboardingViewModel?.failClose()
                return
            }
            guard let self, self.isCurrent(operation) else { return }
            self.discardFailed = false
            self.onboardingViewModel?.finishClose()
            self.clearPresentedFlow()
            self.publish(self.isFeatureEnabled ? .guest : .hidden)
        }
    }

    func recheckSession() {
        guard allows(.recheck), !isBusy else { return }
        if discardFailed {
            beginRestore(droppingPendingWork: true)
            return
        }
        beginRestore(droppingPendingWork: false)
    }

    /// A sibling member feature confirmed an authentication failure. Do not cancel an active
    /// logout/signup operation; recheck after that operation settles instead.
    func recheckSharedSession() {
        guard isFeatureEnabled, presentation == .none else { return }
        guard !isBusy else { sharedRecheckRequested = true; return }
        beginRestore(droppingPendingWork: discardFailed)
    }

    /// Retries the hidden cleanup started while the account flag is off.
    func retryHiddenCleanup() {
        guard !isFeatureEnabled, cleanupBlocked, !isBusy else { return }
        beginOffCleanup()
    }

    func logout() {
        guard allows(.logout), !isBusy else { return }
        let nickname = nickname ?? ""
        begin { [weak self] operation, repository in
            do {
                try await repository.logout()
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.clearPresentedFlow()
                self.publish(.guest)
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                if case .featureUnavailable? = error as? AuthError {
                    self.applyFeatureOff()
                    return
                }
                self.publish(.logoutFailure(nickname: nickname))
            }
        }
    }

    private var isBusy: Bool { accountTask?.isCancelled == false }

    private func beginRestore(droppingPendingWork: Bool) {
        guard isFeatureEnabled else { return }
        publish(.checking)
        clearPresentedFlow()
        begin { [weak self] operation, repository in
            if droppingPendingWork {
                do {
                    try await repository.discardPendingSignup()
                } catch {
                    guard let self, self.isCurrent(operation) else { return }
                    self.discardFailed = true
                    self.publish(.connectionFailure)
                    return
                }
                guard self?.isCurrent(operation) == true, self?.isFeatureEnabled == true else { return }
                self?.discardFailed = false
            }
            do {
                let member = try await repository.restoreSession()
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                if let member {
                    self.publish(.member(nickname: member.nickname))
                } else {
                    self.publish(.guest)
                }
            } catch is CancellationError {
                return
            } catch {
                guard let self, self.isCurrent(operation), self.isFeatureEnabled else { return }
                self.applyRestore(error)
            }
        }
    }

    /// The repository is captured before the task waits. `self` is read again only after that wait,
    /// so a released owner can deinit and cancel the task instead of staying retained by it.
    private func begin(_ work: @escaping @MainActor (UUID, any AuthRepository) async -> Void) {
        accountTask?.cancel()
        invalidateToken = nil
        let operationID = UUID()
        self.operationID = operationID
        let repository = repository
        accountTask = Task { @MainActor [weak self] in
            await work(operationID, repository)
            guard let self, self.isCurrent(operationID) else { return }
            self.accountTask = nil
            self.operationID = nil
            if self.sharedRecheckRequested {
                self.sharedRecheckRequested = false
                self.recheckSharedSession()
            }
        }
    }

    private func isCurrent(_ operationID: UUID) -> Bool {
        self.operationID == operationID && !Task.isCancelled
    }

    private func apply(_ outcome: SignInOutcome) {
        switch outcome {
        case let .member(member):
            finishMember(member)
        case let .signupRequired(suggestedNickname):
            if let suggestedNickname {
                onboardingViewModel = OnboardingViewModel(
                    suggestedNickname: suggestedNickname,
                    allowsConsentAndSubmit: allowsConsentAndSubmit,
                    isMock: isMock
                )
            } else {
                onboardingViewModel = OnboardingViewModel(allowsConsentAndSubmit: allowsConsentAndSubmit, isMock: isMock)
            }
            loginViewModel = nil
            publishPresentation(.signup)
        }
    }

    private func applySignIn(_ error: Error) {
        guard let loginViewModel else { return }
        switch error as? AuthError {
        case .configurationMissing:
            loginViewModel.update(state: .unavailable)
        case .userCancelled:
            loginViewModel.update(state: .cancelled)
        case .emailRegisteredWithOtherProvider:
            loginViewModel.update(state: .emailInUse)
        case .featureUnavailable:
            applyFeatureOff()
        default:
            loginViewModel.update(state: .failure)
        }
    }

    private func applySignup(_ error: Error) {
        guard let onboardingViewModel else { return }
        switch error as? AuthError {
        case let .signupRejected(reason):
            switch reason {
            case .nicknameTaken:
                onboardingViewModel.showEditing(nicknameError: "이미 사용 중인 닉네임이에요.")
            case .invalidInput:
                onboardingViewModel.showEditing(message: "가입 정보를 다시 확인해 주세요.")
            case .consentRequired:
                onboardingViewModel.showEditing(message: "필수 항목을 모두 확인해 주세요.")
            }
        case .featureUnavailable:
            applyFeatureOff()
        case .authenticationInvalid:
            onboardingViewModel.showEditing(message: "로그인 정보가 유효하지 않아요. 닫은 뒤 Google 로그인부터 다시 시작해 주세요.")
        default:
            onboardingViewModel.showUnknownStatus(
                message: "가입 결과를 확인하지 못했어요. 다시 제출하지 말고 완료 여부를 확인해 주세요."
            )
        }
    }

    private func applyRestore(_ error: Error) {
        switch error as? AuthError {
        case .featureUnavailable:
            applyFeatureOff()
        case .authenticationInvalid:
            publish(.guest)
        default:
            publish(.connectionFailure)
        }
    }

    private func applyFeatureOff() {
        isFeatureEnabled = false
        discardFailed = false
        setCleanupBlocked(false)
        publish(.hidden)
        clearPresentedFlow()
    }

    /// Login stays up until discard succeeds. Failure keeps Google disabled and retries cleanup only.
    private func beginLoginCleanup() {
        begin { [weak self] operation, repository in
            do {
                try await repository.discardPendingSignup()
            } catch {
                guard let self, self.isCurrent(operation) else { return }
                self.discardFailed = true
                self.loginViewModel?.update(state: .cleanupFailed)
                return
            }
            guard let self, self.isCurrent(operation) else { return }
            self.discardFailed = false
            switch self.loginCleanup {
            case .cancel:
                if self.loginViewModel?.state == .cancelling {
                    self.loginViewModel?.update(state: .cancelled)
                }
            case .close, .none:
                self.finishCloseLogin()
            }
        }
    }

    private func finishCloseLogin() {
        clearPresentedFlow()
        if isFeatureEnabled, nickname == nil, state != .connectionFailure {
            publish(.guest)
        }
    }

    /// Retries only the cleanup already started for this attempt. It does not restore or sign in.
    /// Failure keeps the account rows hidden and asks for another cleanup without showing a nickname.
    private func beginOffCleanup() {
        begin { [weak self] operation, repository in
            do {
                try await repository.discardPendingSignup()
            } catch {
                guard let self, self.isCurrent(operation) else { return }
                self.discardFailed = true
                self.publish(.hidden)
                self.clearPresentedFlow()
                self.cleanupBlocked = true
                self.cleanupBlockedSubject.send(true)
                return
            }
            guard let self, self.isCurrent(operation) else { return }
            self.discardFailed = false
            self.setCleanupBlocked(false)
            self.publish(.hidden)
            self.clearPresentedFlow()
        }
    }

    private func setCleanupBlocked(_ blocked: Bool) {
        guard cleanupBlocked != blocked else { return }
        cleanupBlocked = blocked
        cleanupBlockedSubject.send(blocked)
    }

    private func finishMember(_ member: Member) {
        clearPresentedFlow()
        publish(.member(nickname: member.nickname))
    }

    private func clearPresentedFlow() {
        loginViewModel = nil
        onboardingViewModel = nil
        publishPresentation(.none)
    }

    private func publish(_ state: State) {
        self.state = state
        stateSubject.send(state)
    }

    private func publishPresentation(_ presentation: Presentation) {
        guard self.presentation != presentation else { return }
        self.presentation = presentation
        presentationSubject.send(presentation)
    }
}

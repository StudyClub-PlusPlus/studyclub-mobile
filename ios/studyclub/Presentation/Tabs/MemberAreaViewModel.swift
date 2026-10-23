import Combine

/// Concrete root composition for profile/Settings and the member list; no global session.
@MainActor
final class MemberAreaViewModel {
    let account: SettingAccountViewModel
    let myStudies: MyStudiesListViewModel
    let isMyPageEnabled: Bool
    private var accountSubscription: AnyCancellable?
    private var isRecheckingListRejection = false

    convenience init() {
        let repositories = RepositoryFactory.makeMemberRepositories()
        let settings = DevelopmentSettingsStore()
        self.init(authRepository: repositories.auth, studiesRepository: repositories.studies,
                  isAuthEnabled: settings.isEnabled(FeatureFlag.googleLogin.definition),
                  isListEnabled: settings.isEnabled(FeatureFlag.myStudies.definition),
                  isMyPageEnabled: settings.isEnabled(FeatureFlag.myPage.definition),
                  isMock: repositories.isMock)
    }

    init(authRepository: any AuthRepository, studiesRepository: any RepositoryProtocol,
         isAuthEnabled: Bool, isListEnabled: Bool, isMyPageEnabled: Bool, isMock: Bool = false) {
        let account = SettingAccountViewModel(repository: authRepository, isFeatureEnabled: isAuthEnabled, isMock: isMock)
        let list = MyStudiesListViewModel(repository: studiesRepository, isFeatureEnabled: isListEnabled, member: nil)
        self.account = account
        self.myStudies = list
        self.isMyPageEnabled = isMyPageEnabled
        list.onAuthenticationRequired = { [weak self] in
            guard let self, self.account.presentation == .none else { return }
            self.isRecheckingListRejection = true
            self.account.recheckSharedSession()
        }
        list.onSessionRecheck = { [weak self] in
            guard let self else { return }
            self.isRecheckingListRejection = false
            self.account.recheckSharedSession()
        }
        accountSubscription = account.statePublisher.sink { [weak self] state in
            self?.updateList(for: state)
        }
    }

    private func updateList(for state: SettingAccountViewModel.State) {
        switch state {
        case let .member(nickname):
            if isRecheckingListRejection {
                // Membership alone does not authorize a list that the server just rejected.
                // Keep the failure for an explicit user retry instead of starting a request loop.
                isRecheckingListRejection = false
                myStudies.suspend(state: .failure)
            } else {
                myStudies.updateSession(Member(nickname: nickname))
            }
        case let .logoutFailure(nickname):
            if !isRecheckingListRejection { myStudies.updateSession(Member(nickname: nickname)) }
        case .guest:
            isRecheckingListRejection = false
            myStudies.updateSession(nil)
        case .hidden:
            isRecheckingListRejection = false
            myStudies.suspend(state: .unavailable)
        case .checking:
            // Retain the specific guest instruction while its one auth recheck is pending.
            if !isRecheckingListRejection { myStudies.suspend(state: .loading) }
        case .connectionFailure:
            isRecheckingListRejection = false
            myStudies.suspend(state: .failure)
        }
    }

    func invalidate() async throws {
        isRecheckingListRejection = false
        myStudies.suspend(state: .loading)
        try await account.invalidate()
    }
}

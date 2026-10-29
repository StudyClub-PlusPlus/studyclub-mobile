import Combine
import UIKit

@MainActor
class SettingViewController: UIViewController, UICollectionViewDelegate {
    private enum Section: Hashable {
        case account, logout
    }

    private enum Row: Hashable {
        case header, checking, login, member, logout, failure, retry, retryLogout
    }

    let viewModel: SettingAccountViewModel
    var onAccountFlowDismissed: (() -> Void)?
    /// The account view model presents login and owns its return path.
    var onLoginRequested: (() -> Void)?
    var onAccountActionRequested: ((SettingAccountViewModel.Action) -> Void)?
    private var accountNavigation: UINavigationController?
    private var cleanupAlert: UIAlertController?
    /// The user closed the hidden-cleanup alert without clearing the blocked cleanup.
    private var cleanupDeferred = false
    /// Settings tab was no longer selected after that close, so the next visit can offer retry.
    private var cleanupLeftScreen = false
    /// Tells the tab root that a failed repository swap can be retried.
    var onSessionSettled: ((SettingAccountViewModel.State) -> Void)?
    private var subscriptions = Set<AnyCancellable>()
    private var dataSource: UICollectionViewDiffableDataSource<Section, Row>!
    private let listView: UICollectionView = {
        let layout = UICollectionViewCompositionalLayout { sectionIndex, environment in
            var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
            configuration.backgroundColor = AppTheme.Palette.canvas
            // Only the account group has a title; logout is an independent action group.
            configuration.headerMode = sectionIndex == 0 ? .firstItemInSection : .none
            configuration.separatorConfiguration.color = AppTheme.Palette.border
            return NSCollectionLayoutSection.list(using: configuration, layoutEnvironment: environment)
        }
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init() {
        self.init(viewModel: SettingAccountViewModel())
    }

    init(viewModel: SettingAccountViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
        onLoginRequested = { [weak viewModel] in viewModel?.startLogin() }
        onAccountActionRequested = { [weak viewModel] action in
            switch action {
            case .login: viewModel?.startLogin()
            case .recheck: viewModel?.recheckSession()
            case .logout: viewModel?.logout()
            }
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        viewModel.statePublisher.sink { [weak self] state in
            self?.updateViews()
            self?.onSessionSettled?(state)
        }.store(in: &subscriptions)
        viewModel.presentationPublisher.sink { [weak self] _ in
            self?.updateAccountPresentation()
        }.store(in: &subscriptions)
        viewModel.cleanupBlockedPublisher.sink { [weak self] blocked in
            self?.updateCleanupAlert(blocked)
        }.store(in: &subscriptions)
    }

    private func updateCleanupAlert(_ blocked: Bool) {
        guard blocked else {
            cleanupDeferred = false
            cleanupLeftScreen = false
            guard let alert = cleanupAlert else { return }
            cleanupAlert = nil
            if presentedViewController === alert { dismiss(animated: false) }
            return
        }
        presentCleanupAlertIfVisible()
    }

    private func presentCleanupAlertIfVisible() {
        guard viewModel.cleanupBlocked, !cleanupDeferred, cleanupAlert == nil else { return }
        guard isCleanupScreenVisible else { return }
        let alert = UIAlertController(
            title: "로그인 정리를 끝내지 못했어요.",
            message: "계정 정보는 표시하지 않아요. 지금 다시 시도하거나, 나중에 설정에서 다시 확인할 수 있어요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel) { [weak self] _ in
            self?.cleanupAlert = nil
            self?.cleanupDeferred = true
        })
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in
            self?.cleanupAlert = nil
            self?.cleanupDeferred = false
            self?.viewModel.retryHiddenCleanup()
        })
        cleanupAlert = alert
        present(alert, animated: true)
    }

    private var isCleanupScreenVisible: Bool {
        guard isViewLoaded, view.window != nil, presentedViewController == nil else { return false }
        if let tab = tabBarController {
            let selected = tab.selectedViewController
            return selected === self || selected === navigationController
        }
        return true
    }

    func invalidateAccountWorkflow() async throws {
        let navigation = accountNavigation
        accountNavigation = nil
        do {
            try await viewModel.invalidate()
        } catch {
            if let navigation, presentedViewController === navigation {
                dismiss(animated: false)
            }
            throw error
        }
        if let navigation, presentedViewController === navigation {
            dismiss(animated: false)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFeatureVisibility()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        // Alert dismissal can omit appearance callbacks and still leaves Settings selected.
        // Only a real tab change may arm the next visit.
        guard cleanupDeferred, !isCleanupTabSelected else { return }
        cleanupLeftScreen = true
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if cleanupLeftScreen {
            cleanupLeftScreen = false
            cleanupDeferred = false
        }
        presentCleanupAlertIfVisible()
    }

    private var isCleanupTabSelected: Bool {
        guard let tab = tabBarController else { return true }
        let selected = tab.selectedViewController
        return selected === self || selected === navigationController
    }

    func refreshFeatureVisibility() {
        viewModel.updateFeatureVisibility(
            isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
        )
    }

    func configureView() {
        title = "설정"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas
        view.tintColor = AppTheme.Palette.accent

        view.addSubview(listView)
        listView.delegate = self
        let registration = UICollectionView.CellRegistration<UICollectionViewListCell, Row> { [weak self] cell, _, row in
            cell.configurationUpdateHandler = { [weak self] cell, _ in
                guard let cell = cell as? UICollectionViewListCell else { return }
                self?.configure(cell, row: row)
            }
            self?.configure(cell, row: row)
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Row>(collectionView: listView) { collection, indexPath, row in
            collection.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: row)
        }
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configure(_ cell: UICollectionViewListCell, row: Row) {
        var content = row == .header ? UIListContentConfiguration.header() : UIListContentConfiguration.cell()
        content.textProperties.numberOfLines = 0
        content.secondaryTextProperties.numberOfLines = 0
        content.textProperties.color = row == .header ? AppTheme.Palette.secondaryText : AppTheme.Palette.primaryText
        content.secondaryTextProperties.color = AppTheme.Palette.secondaryText
        var background = UIBackgroundConfiguration.listCell()
        background.backgroundColor = row == .header ? .clear : AppTheme.Palette.surface
        cell.backgroundConfiguration = background
        cell.accessories = []
        switch row {
        case .header:
            content.text = "계정"
        case .checking:
            content.text = "로그인 상태를 확인하고 있어요…"
            let spinner = UIActivityIndicatorView(style: .medium)
            spinner.color = AppTheme.Palette.accent
            spinner.startAnimating()
            cell.accessories = [.customView(configuration: .init(customView: spinner, placement: .trailing()))]
        case .login:
            content.text = "로그인"
            content.secondaryText = "Google 계정으로 로그인하세요"
            cell.accessories = [.disclosureIndicator()]
        case .member:
            content.text = viewModel.nickname
            content.secondaryText = "로그인됨"
        case .logout, .retryLogout:
            content.text = row == .logout ? "로그아웃" : "로그아웃 다시 시도"
            content.textProperties.color = AppTheme.Palette.error
        case .failure:
            if case .logoutFailure = viewModel.state {
                content.text = "로그아웃하지 못했어요. 다시 시도해 주세요."
            } else {
                content.text = "로그인 상태를 확인하지 못했어요."
                content.secondaryText = "연결을 확인하고 다시 확인해 주세요."
            }
        case .retry:
            content.text = "다시 확인"
            content.textProperties.color = AppTheme.Palette.accent
        }
        cell.contentConfiguration = content
    }

    func updateViews() {
        let accountRows: [Row]
        let logoutRows: [Row]
        switch viewModel.state {
        case .hidden:
            accountRows = []
            logoutRows = []
        case .guest:
            accountRows = [.login]
            logoutRows = []
        case .checking:
            accountRows = [.checking]
            logoutRows = []
        case .connectionFailure:
            accountRows = [.failure, .retry]
            logoutRows = []
        case .member:
            accountRows = [.member]
            logoutRows = [.logout]
        case .logoutFailure:
            accountRows = [.member]
            logoutRows = [.failure, .retryLogout]
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, Row>()
        if !accountRows.isEmpty {
            snapshot.appendSections([.account])
            snapshot.appendItems([.header] + accountRows, toSection: .account)
        }
        if !logoutRows.isEmpty {
            snapshot.appendSections([.logout])
            snapshot.appendItems(logoutRows, toSection: .logout)
        }
        let existingRows = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter { existingRows.contains($0) })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateAccountPresentation() {
        switch viewModel.presentation {
        case .none:
            guard let navigation = accountNavigation else { return }
            accountNavigation = nil
            if presentedViewController === navigation {
                dismiss(animated: true) { [weak self] in self?.onAccountFlowDismissed?() }
            } else {
                onAccountFlowDismissed?()
            }
        case .login:
            guard accountNavigation == nil, let loginViewModel = viewModel.loginViewModel else { return }
            let login = LoginViewController(
                viewModel: loginViewModel,
                onGoogleSignIn: { [weak self] _ in self?.viewModel.signInWithGoogle() },
                onAppleSignIn: { [weak self] in self?.viewModel.signInWithApple() },
                onCancelSignIn: { [weak self] in self?.viewModel.cancelSignIn() },
                onRetryCleanup: { [weak self] in self?.viewModel.retryLoginCleanup() },
                onClose: { [weak self] in self?.viewModel.closeLogin() }
            )
            presentAccount(login)
        case .signup:
            guard let onboardingViewModel = viewModel.onboardingViewModel else { return }
            let onboarding = OnboardingViewController(
                viewModel: onboardingViewModel,
                onSubmit: { [weak self] input in self?.viewModel.submitSignup(input) },
                onRecheck: { [weak self] in self?.viewModel.recheckSignup() },
                onRetryCleanup: { [weak self] in self?.viewModel.retryAbandonSignup() },
                onClose: { [weak self] in self?.viewModel.abandonSignup() }
            )
            if let navigation = accountNavigation {
                navigation.setViewControllers([onboarding], animated: true)
            } else {
                presentAccount(onboarding)
            }
        }
    }

    private func presentAccount(_ root: UIViewController) {
        let navigation = UINavigationController(rootViewController: root)
        navigation.modalPresentationStyle = .fullScreen
        navigation.isModalInPresentation = true
        accountNavigation = navigation
        present(navigation, animated: true)
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        collectionView.deselectItem(at: indexPath, animated: true)
        // Resolve stable identity before a flag update can replace the snapshot.
        guard let row = dataSource.itemIdentifier(for: indexPath) else { return }
        refreshFeatureVisibility()
        switch row {
        case .login:
            guard viewModel.allows(.login), presentedViewController == nil else { return }
            onLoginRequested?()
        case .logout, .retryLogout:
            confirmLogout()
        case .retry:
            requestAccountAction(.recheck)
        default: break
        }
    }

    func requestAccountAction(_ action: SettingAccountViewModel.Action) {
        refreshFeatureVisibility()
        guard viewModel.allows(action) else { return }
        onAccountActionRequested?(action)
    }

    func confirmLogout() {
        guard viewModel.allows(.logout), presentedViewController == nil else { return }
        let alert = UIAlertController(title: "로그아웃할까요?", message: nil, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "취소", style: .cancel))
        alert.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in self?.requestAccountAction(.logout) })
        present(alert, animated: true)
    }
}

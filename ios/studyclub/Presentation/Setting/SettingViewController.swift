import Combine
import UIKit

@MainActor
final class SettingViewController: UIViewController, UICollectionViewDelegate {
    private enum Section: Hashable {
        case account, logout
    }

    private enum Row: Hashable {
        case header, checking, login, member, logout, failure, retry, retryLogout
    }

    private let viewModel: SettingAccountViewModel
    /// The connection slice presents login and owns its return path.
    var onLoginRequested: (() -> Void)?
    var onAccountActionRequested: ((SettingAccountViewModel.Action) -> Void)?
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
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        viewModel.statePublisher.sink { [weak self] _ in
            self?.updateViews()
        }.store(in: &subscriptions)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        refreshFeatureVisibility()
    }

    func refreshFeatureVisibility() {
        viewModel.updateFeatureVisibility(
            isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
        )
    }

    private func configureView() {
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

    private func updateViews() {
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
            guard viewModel.allows(.logout), presentedViewController == nil else { return }
            let alert = UIAlertController(title: "로그아웃할까요?", message: nil, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "취소", style: .cancel))
            alert.addAction(UIAlertAction(title: "로그아웃", style: .destructive) { [weak self] _ in
                self?.requestAccountAction(.logout)
            })
            present(alert, animated: true)
        case .retry:
            requestAccountAction(.recheck)
        default: break
        }
    }

    private func requestAccountAction(_ action: SettingAccountViewModel.Action) {
        refreshFeatureVisibility()
        guard viewModel.allows(action) else { return }
        onAccountActionRequested?(action)
    }
}

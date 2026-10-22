import Combine
import UIKit

@MainActor
final class MyStudiesListViewController: UIViewController {
    private enum Section { case studies }
    private let viewModel: MyStudiesListViewModel
    var onLogin: (() -> Void)?
    var onSelectStudy: ((Study.ID) -> Void)?
    private var cancellables = Set<AnyCancellable>()
    private var itemsByID: [Study.ID: StudyCardCellViewModel] = [:]
    private var dataSource: UICollectionViewDiffableDataSource<Section, Study.ID>!

    private let collectionView: UICollectionView = {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(176))
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [NSCollectionLayoutItem(layoutSize: size)])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = AppTheme.Spacing.medium
        section.contentInsets = .init(top: 16, leading: 16, bottom: 24, trailing: 16)
        let view = UICollectionView(frame: .zero, collectionViewLayout: UICollectionViewCompositionalLayout(section: section))
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let refreshControl = UIRefreshControl()
    private let stateStack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = AppTheme.Spacing.medium
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let activity: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.color = AppTheme.Palette.accent
        view.hidesWhenStopped = true
        return view
    }()
    private let stateImage: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.tintColor = AppTheme.Palette.secondaryText
        view.preferredSymbolConfiguration = .init(pointSize: 32)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let stateTitle: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .headline)
        view.textColor = AppTheme.Palette.primaryText
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    private let stateMessage: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    private let loginButton: UIButton = {
        let view = UIButton(type: .system)
        view.configuration = .filled()
        view.setTitle("로그인하기", for: .normal)
        view.tintColor = AppTheme.Palette.accent
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    init(viewModel: MyStudiesListViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        let registration = UICollectionView.CellRegistration<StudyCardCell, StudyCardCellViewModel> { cell, _, item in
            cell.updateViews(with: item)
        }
        dataSource = .init(collectionView: collectionView) { [weak self] collection, index, id in
            guard let item = self?.itemsByID[id] else { return nil }
            return collection.dequeueConfiguredReusableCell(using: registration, for: index, item: item)
        }
        viewModel.statePublisher.sink { [weak self] _ in self?.updateViews() }.store(in: &cancellables)
    }

    private func configureView() {
        title = "내 스터디"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas

        view.addSubview(collectionView)
        collectionView.delegate = self
        refreshControl.addTarget(self, action: #selector(refresh), for: .valueChanged)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(stateStack)
        NSLayoutConstraint.activate([
            stateStack.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stateStack.centerXAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerXAnchor),
            stateStack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            stateStack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            stateStack.topAnchor.constraint(greaterThanOrEqualTo: view.safeAreaLayoutGuide.topAnchor, constant: 16),
            stateStack.bottomAnchor.constraint(lessThanOrEqualTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -16)
        ])
        stateStack.addArrangedSubview(activity)
        stateStack.addArrangedSubview(stateImage)
        NSLayoutConstraint.activate([stateImage.widthAnchor.constraint(equalToConstant: 44), stateImage.heightAnchor.constraint(equalToConstant: 44)])
        stateStack.addArrangedSubview(stateTitle)
        stateStack.addArrangedSubview(stateMessage)
        stateStack.addArrangedSubview(loginButton)
        loginButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        loginButton.addTarget(self, action: #selector(login), for: .touchUpInside)
    }

    private func updateViews() {
        if !viewModel.isRefreshing { refreshControl.endRefreshing() }
        navigationItem.prompt = viewModel.state == .content ? viewModel.message : nil
        let state = viewModel.state
        let canRefresh = state == .content || state == .empty || state == .failure
        collectionView.refreshControl = canRefresh ? refreshControl : nil
        collectionView.isScrollEnabled = canRefresh
        stateStack.isHidden = state == .content
        // Empty/failure pass pull gestures through to the native refresh control below.
        stateStack.isUserInteractionEnabled = state == .guest
        loginButton.isHidden = state != .guest
        stateImage.isHidden = state == .loading
        stateImage.tintColor = state == .failure ? AppTheme.Palette.error : AppTheme.Palette.secondaryText
        activity.stopAnimating()
        switch state {
        case .loading:
            activity.startAnimating()
            stateTitle.text = "내 스터디를 불러오는 중이에요"
            stateMessage.text = "잠시만 기다려 주세요."
        case .content: break
        case .empty:
            stateImage.image = UIImage(systemName: "tray")
            stateTitle.text = "참여 중인 스터디가 없어요"
            stateMessage.text = "새로운 스터디를 찾아 참여해 보세요."
        case .failure:
            stateImage.image = UIImage(systemName: "exclamationmark.triangle")
            stateTitle.text = "내 스터디를 불러오지 못했어요"
            stateMessage.text = "아래로 당겨 다시 불러와 주세요."
        case .guest:
            stateImage.image = UIImage(systemName: "person.crop.circle")
            stateTitle.text = "로그인하고 내 스터디를 확인해 보세요."
            stateMessage.text = viewModel.message ?? "참여한 스터디를 한곳에서 볼 수 있어요."
        case .unavailable:
            stateImage.image = UIImage(systemName: "info.circle")
            stateTitle.text = "아직 제공되지 않는 기능이에요"
            stateMessage.text = "내 스터디 목록은 준비 중이에요."
        }
        let items = viewModel.items
        let previous = dataSource.snapshot()
        let previousIDs = Set(previous.itemIdentifiers)
        let changed = items.compactMap { item in previousIDs.contains(item.id) && itemsByID[item.id] != item ? item.id : nil }
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
        snapshot.appendSections([.studies])
        snapshot.appendItems(items.map(\.id))
        snapshot.reconfigureItems(changed)
        dataSource.apply(snapshot, animatingDifferences: view.window != nil)
    }

    @objc private func login() { onLogin?() }
    @objc private func refresh() { viewModel.refresh() }
}

extension MyStudiesListViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer { collectionView.deselectItem(at: indexPath, animated: true) }
        guard let id = dataSource.itemIdentifier(for: indexPath), let selected = viewModel.selectedStudyID(id) else { return }
        onSelectStudy?(selected)
    }
}

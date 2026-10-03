import Combine
import UIKit

@MainActor
final class MainViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: MainViewModel
    private let collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: MainViewController.makeLayout())
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let stateView: ContentStateView = {
        let view = ContentStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let refreshControl = UIRefreshControl()
    private var dataSource: UICollectionViewDiffableDataSource<Section, Study.ID>!
    private var itemsByID: [Study.ID: StudyCardCellViewModel] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MainViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureDataSource()
        configureFooter()
        bindViewModel()
    }

    private func configureView() {
        title = "스터디"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas

        view.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.refreshControl = refreshControl
        refreshControl.addTarget(self, action: #selector(refreshList), for: .valueChanged)
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(stateView)
        // The existing collection receives pull gestures even while a state surface is shown.
        stateView.isUserInteractionEnabled = false
        stateView.backgroundColor = .clear
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<StudyCardCell, StudyCardCellViewModel> {
            cell, _, item in
            cell.updateViews(with: item)
        }

        dataSource = UICollectionViewDiffableDataSource<Section, Study.ID>(collectionView: collectionView) {
            [weak self] collectionView, indexPath, itemIdentifier in
            guard
                let self,
                let item = self.itemsByID[itemIdentifier]
            else {
                return nil
            }
            return collectionView.dequeueConfiguredReusableCell(
                using: registration,
                for: indexPath,
                item: item
            )
        }
    }

    private func configureFooter() {
        let registration = UICollectionView.SupplementaryRegistration<StudyListFooterView>(
            elementKind: UICollectionView.elementKindSectionFooter
        ) { [weak self] footer, _, _ in
            guard let self else { return }
            footer.retryButton.removeTarget(nil, action: nil, for: .touchUpInside)
            footer.retryButton.addTarget(self, action: #selector(self.retryPage), for: .touchUpInside)
            footer.updateViews(self.viewModel.pageState)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: registration, for: indexPath)
        }
    }

    @objc private func refreshList() { viewModel.refresh() }
    @objc private func retryPage() { viewModel.retryPage() }

    private func bindViewModel() {
        viewModel.statePublisher
            .sink { [weak self] _ in
                self?.updateViews()
            }
            .store(in: &cancellables)
    }

    private func updateViews() {
        if !viewModel.isRefreshing { refreshControl.endRefreshing() }
        navigationItem.prompt = viewModel.refreshError
        let items = viewModel.items
        let previousItems = itemsByID
        let previousIDs = Set(dataSource.snapshot().itemIdentifiers)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(items.map(\.id), toSection: .main)
        snapshot.reconfigureItems(items.compactMap { item in
            previousIDs.contains(item.id) && previousItems[item.id] != item ? item.id : nil
        })
        dataSource.apply(snapshot, animatingDifferences: view.window != nil) { [weak self] in
            self?.loadMoreIfNeeded()
        }
        collectionView.isHidden = false
        switch viewModel.currentState {
        case .loading: stateView.updateViews(.loading)
        case .content: stateView.isHidden = true
        case .empty: stateView.updateViews(.empty)
        case .failure: stateView.updateViews(.failure)
        }
        for case let footer as StudyListFooterView in collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionFooter
        ) {
            footer.updateViews(viewModel.pageState)
        }
    }

    private func loadMoreIfNeeded() {
        guard viewModel.currentState == .content else { return }
        let remaining = collectionView.contentSize.height
            - collectionView.contentOffset.y - collectionView.bounds.height
        if remaining < collectionView.bounds.height { viewModel.loadMore() }
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(176)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(72)),
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
        ]
        section.interGroupSpacing = AppTheme.Spacing.medium
        section.contentInsets = NSDirectionalEdgeInsets(
            top: AppTheme.Spacing.regular,
            leading: AppTheme.Spacing.regular,
            bottom: AppTheme.Spacing.xLarge,
            trailing: AppTheme.Spacing.regular
        )
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension MainViewController: UICollectionViewDelegate {
    func scrollViewDidScroll(_ scrollView: UIScrollView) { loadMoreIfNeeded() }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer { collectionView.deselectItem(at: indexPath, animated: true) }
        guard
            let studyID = dataSource.itemIdentifier(for: indexPath),
            viewModel.study(for: studyID) != nil
        else {
            return
        }

        let detailViewModel = DetailViewModel(studyID: studyID)
        let detailViewController = DetailViewController(viewModel: detailViewModel)
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

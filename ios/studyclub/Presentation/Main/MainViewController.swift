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
    private var studySearchController: UISearchController?
    private var searchResultsController: SearchResultsViewController?
    private var pendingSearchSelection: Study.ID?
    private var browseOffsetBeforeSearch: CGPoint?

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
        if viewModel.isListAPIEnabled { configureFooter() }
        bindViewModel()
        if viewModel.isSearchEnabled { configureSearch() }
    }

    private func configureSearch() {
        let results = SearchResultsViewController(viewModel: StudySearchViewModel())
        let controller = UISearchController(searchResultsController: results)
        results.onSelectStudy = { [weak self, weak controller] id in
            self?.pendingSearchSelection = id
            controller?.isActive = false
        }
        controller.searchResultsUpdater = self
        controller.delegate = self
        controller.searchBar.delegate = self
        controller.obscuresBackgroundDuringPresentation = false
        controller.automaticallyShowsSearchResultsController = false
        controller.searchBar.placeholder = "스터디 검색"
        navigationItem.searchController = controller
        navigationItem.hidesSearchBarWhenScrolling = false
        definesPresentationContext = true
        studySearchController = controller
        searchResultsController = results
    }

    private func showDetail(studyID: Study.ID) {
        let detail = DetailViewController(viewModel: DetailViewModel(studyID: studyID))
        navigationController?.pushViewController(detail, animated: true)
    }

    private func configureView() {
        title = "스터디"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas

        view.addSubview(collectionView)
        collectionView.delegate = self
        collectionView.setCollectionViewLayout(
            Self.makeLayout(isListAPIEnabled: viewModel.isListAPIEnabled), animated: false
        )
        if viewModel.isListAPIEnabled {
            collectionView.refreshControl = refreshControl
            refreshControl.addTarget(self, action: #selector(refreshList), for: .valueChanged)
        }
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(stateView)
        if viewModel.isListAPIEnabled {
            // ON keeps pull gestures available while a state surface is shown.
            stateView.isUserInteractionEnabled = false
            stateView.backgroundColor = .clear
        }
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
        if !viewModel.isListAPIEnabled {
            // OFF keeps the one-request surface; it has no refresh or pagination.
            collectionView.isHidden = viewModel.currentState != .content
            switch viewModel.currentState {
            case .content:
                stateView.isHidden = true
                let items = viewModel.items
                itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
                var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
                snapshot.appendSections([.main])
                snapshot.appendItems(items.map(\.id), toSection: .main)
                dataSource.apply(snapshot, animatingDifferences: view.window != nil)
            case .loading: stateView.updateViews(.loading)
            case .empty: stateView.updateViews(.empty)
            case .failure: stateView.updateViews(.failure)
            case .unavailable: stateView.updateViews(.unavailable)
            }
            return
        }
        if !viewModel.isRefreshing { refreshControl.endRefreshing() }
        navigationItem.prompt = viewModel.refreshError
        collectionView.isHidden = false
        switch viewModel.currentState {
        case .loading: stateView.updateViews(.loading)
        case .content: stateView.isHidden = true
        case .empty: stateView.updateViews(.empty)
        case .failure: stateView.updateViews(.failure)
        case .unavailable: stateView.updateViews(.unavailable)
        }
        for case let footer as StudyListFooterView in collectionView.visibleSupplementaryViews(
            ofKind: UICollectionView.elementKindSectionFooter
        ) {
            footer.updateViews(viewModel.pageState)
        }
        updateSnapshot()
    }

    private func updateSnapshot() {
        let items = viewModel.items
        let currentSnapshot = dataSource.snapshot()
        let ids = items.map(\.id)
        guard currentSnapshot.sectionIdentifiers.isEmpty
            || currentSnapshot.itemIdentifiers != ids
            || items.contains(where: { itemsByID[$0.id] != $0 })
        else {
            // An unchanged successful page can still advance the raw cursor.
            loadMoreIfNeeded()
            return
        }
        let previousItems = itemsByID
        let previousIDs = Set(currentSnapshot.itemIdentifiers)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
        snapshot.appendSections([.main])
        snapshot.appendItems(ids, toSection: .main)
        snapshot.reconfigureItems(items.compactMap { item in
            previousIDs.contains(item.id) && previousItems[item.id] != item ? item.id : nil
        })
        dataSource.apply(snapshot, animatingDifferences: view.window != nil) { [weak self] in
            self?.loadMoreIfNeeded()
        }
    }

    private func loadMoreIfNeeded() {
        guard studySearchController?.isActive != true,
              viewModel.isListAPIEnabled, viewModel.currentState == .content else { return }
        let remaining = collectionView.contentSize.height
            - collectionView.contentOffset.y - collectionView.bounds.height
        if remaining < collectionView.bounds.height { viewModel.loadMore() }
    }

    private static func makeLayout(isListAPIEnabled: Bool = true) -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(176)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.boundarySupplementaryItems = isListAPIEnabled ? [
            NSCollectionLayoutBoundarySupplementaryItem(
                layoutSize: NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(72)),
                elementKind: UICollectionView.elementKindSectionFooter,
                alignment: .bottom
            )
        ] : []
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

        showDetail(studyID: studyID)
    }
}

extension MainViewController: UISearchResultsUpdating, UISearchControllerDelegate, UISearchBarDelegate {
    func searchBarShouldBeginEditing(_ searchBar: UISearchBar) -> Bool {
        // Capture before UISearchController changes the host navigation bar's insets.
        if browseOffsetBeforeSearch == nil {
            browseOffsetBeforeSearch = collectionView.contentOffset
        }
        return true
    }

    func updateSearchResults(for searchController: UISearchController) {
        guard searchController.isActive else { return }
        searchController.showsSearchResultsController = true
        let field = searchController.searchBar.searchTextField
        searchResultsController?.updateInput(field.text ?? "", isComposing: field.markedTextRange != nil)
    }

    func willPresentSearchController(_ searchController: UISearchController) {
        searchController.showsSearchResultsController = true
    }

    func willDismissSearchController(_ searchController: UISearchController) {
        searchResultsController?.endSearch()
        searchController.searchBar.text = ""
    }

    func didDismissSearchController(_ searchController: UISearchController) {
        if let offset = browseOffsetBeforeSearch {
            collectionView.setContentOffset(offset, animated: false)
        }
        browseOffsetBeforeSearch = nil
        // Recompute the collapsed title after search restores the browse offset.
        navigationController?.navigationBar.setNeedsLayout()
        navigationController?.navigationBar.layoutIfNeeded()
        if let id = pendingSearchSelection {
            pendingSearchSelection = nil
            // Search IDs are public identities; they need not occur in the recruiting browse list.
            showDetail(studyID: id)
        }
    }
}

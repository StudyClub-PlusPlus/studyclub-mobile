import Combine
import UIKit

final class SearchResultsViewController: UIViewController {
    private enum Section { case results }
    private let viewModel: StudySearchViewModel
    var onSelectStudy: ((Study.ID) -> Void)?
    private let phaseButton = UIButton(type: .system)
    private let categoryButton = UIButton(type: .system)
    private let filterStack: UIStackView = {
        let view = UIStackView()
        view.axis = .horizontal
        view.spacing = AppTheme.Spacing.small
        view.distribution = .fillEqually
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let collectionView: UICollectionView = {
        let view = UICollectionView(frame: .zero, collectionViewLayout: makeLayout())
        view.backgroundColor = .clear
        view.keyboardDismissMode = .onDrag
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let stateView: ContentStateView = {
        let view = ContentStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let pageButton: UIButton = {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var dataSource: UICollectionViewDiffableDataSource<Section, Study.ID>!
    private var itemsByID: [Study.ID: StudyCardCellViewModel] = [:]
    private var cancelBag = Set<AnyCancellable>()

    init(viewModel: StudySearchViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureDataSource()
        setSubscription()
    }

    func updateInput(_ text: String, isComposing: Bool) {
        viewModel.updateInput(text, isComposing: isComposing)
    }

    func endSearch() { viewModel.endSearch() }

    private func configureView() {
        view.backgroundColor = AppTheme.Palette.canvas
        view.tintColor = AppTheme.Palette.accent
        view.addSubview(filterStack)
        filterStack.addArrangedSubview(phaseButton)
        filterStack.addArrangedSubview(categoryButton)
        NSLayoutConstraint.activate([
            filterStack.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: AppTheme.Spacing.small),
            filterStack.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.regular),
            filterStack.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.regular),
            filterStack.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        ])

        view.addSubview(pageButton)
        pageButton.addTarget(self, action: #selector(didTapPageButton), for: .touchUpInside)
        NSLayoutConstraint.activate([
            pageButton.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor),
            pageButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: AppTheme.Spacing.regular),
            pageButton.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -AppTheme.Spacing.regular),
            pageButton.heightAnchor.constraint(equalToConstant: 44)
        ])

        view.addSubview(collectionView)
        collectionView.delegate = self
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: filterStack.bottomAnchor, constant: AppTheme.Spacing.small),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: pageButton.topAnchor)
        ])

        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: collectionView.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: collectionView.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<StudyCardCell, StudyCardCellViewModel> { cell, _, item in
            cell.updateViews(with: item)
        }
        dataSource = UICollectionViewDiffableDataSource<Section, Study.ID>(collectionView: collectionView) {
            [weak self] collectionView, indexPath, id in
            guard let item = self?.itemsByID[id] else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: registration, for: indexPath, item: item)
        }
    }

    private func setSubscription() {
        viewModel.statePublisher.sink { [weak self] _ in self?.updateViews() }.store(in: &cancelBag)
    }

    private func updateViews() {
        updateFilters()
        let state = viewModel.currentState
        collectionView.isHidden = state != .content
        switch state {
        case .idle, .content: stateView.isHidden = true
        case .loading: stateView.updateViews(.loading, context: .search)
        case .empty: stateView.updateViews(.empty, context: .search)
        case .failure: stateView.updateViews(.failure, context: .search)
        }

        var pageConfiguration = UIButton.Configuration.plain()
        switch viewModel.pageState {
        case .idle: pageConfiguration.title = state == .failure ? "다시 검색" : "더 보기"
        case .loading:
            pageConfiguration.title = "불러오는 중이에요"
            pageConfiguration.showsActivityIndicator = true
        case .failure: pageConfiguration.title = "다음 결과 다시 시도"
        case .stalled: pageConfiguration.title = "처음부터 다시 검색"
        }
        pageButton.configuration = pageConfiguration
        pageButton.isHidden = !viewModel.canLoadMore && state != .failure
        pageButton.isEnabled = viewModel.pageState != .loading

        let items = viewModel.items
        let oldItems = itemsByID
        let oldIDs = Set(dataSource.snapshot().itemIdentifiers)
        itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
        snapshot.appendSections([.results])
        snapshot.appendItems(items.map(\.id))
        snapshot.reconfigureItems(items.compactMap { oldIDs.contains($0.id) && oldItems[$0.id] != $0 ? $0.id : nil })
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func updateFilters() {
        let phases: [(StudyPhase?, String)] = [(nil, "전체"), (.recruiting, "모집 중"), (.ongoing, "진행 중"), (.closed, "종료")]
        phaseButton.menu = UIMenu(title: "상태", children: phases.map { phase, title in
            UIAction(title: title, state: viewModel.query.phase == phase ? .on : .off) { [weak self] _ in
                self?.viewModel.selectPhase(phase)
            }
        })
        var phaseConfiguration = UIButton.Configuration.tinted()
        phaseConfiguration.title = "상태 · \(phases.first { $0.0 == viewModel.query.phase }?.1 ?? "전체")"
        phaseConfiguration.image = UIImage(systemName: "chevron.down")
        phaseConfiguration.imagePlacement = .trailing
        phaseConfiguration.imagePadding = AppTheme.Spacing.small
        phaseButton.configuration = phaseConfiguration
        phaseButton.showsMenuAsPrimaryAction = true

        let categories: [(StudyCategory?, String)] = [(nil, "전체")] + StudyCategory.allCases.map { ($0, $0.displayText) }
        categoryButton.menu = UIMenu(title: "카테고리", children: categories.map { category, title in
            UIAction(title: title, state: viewModel.query.category == category ? .on : .off) { [weak self] _ in
                self?.viewModel.selectCategory(category)
            }
        })
        var categoryConfiguration = phaseConfiguration
        categoryConfiguration.title = "분야 · \(viewModel.query.category?.displayText ?? "전체")"
        categoryButton.configuration = categoryConfiguration
        categoryButton.showsMenuAsPrimaryAction = true
    }

    @objc private func didTapPageButton() {
        if viewModel.currentState == .failure || viewModel.pageState == .failure || viewModel.pageState == .stalled {
            viewModel.retry()
        } else {
            viewModel.loadMore()
        }
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let size = NSCollectionLayoutSize(widthDimension: .fractionalWidth(1), heightDimension: .estimated(176))
        let item = NSCollectionLayoutItem(layoutSize: size)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: size, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
        section.interGroupSpacing = AppTheme.Spacing.medium
        section.contentInsets = NSDirectionalEdgeInsets(top: AppTheme.Spacing.small, leading: AppTheme.Spacing.regular,
                                                       bottom: AppTheme.Spacing.regular, trailing: AppTheme.Spacing.regular)
        return UICollectionViewCompositionalLayout(section: section)
    }
}

extension SearchResultsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer { collectionView.deselectItem(at: indexPath, animated: true) }
        guard let id = dataSource.itemIdentifier(for: indexPath), itemsByID[id] != nil else { return }
        onSelectStudy?(id)
    }
}

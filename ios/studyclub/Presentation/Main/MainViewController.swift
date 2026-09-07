import Combine
import UIKit

@MainActor
final class MainViewController: UIViewController {
    private enum Section {
        case main
    }

    private let viewModel: MainViewModel
    private let repository: any RepositoryProtocol
    private let collectionView: UICollectionView
    private let stateView = ContentStateView()
    private var dataSource: UICollectionViewDiffableDataSource<Section, Study.ID>!
    private var itemsByID: [Study.ID: StudyListItemViewData] = [:]
    private var cancellables = Set<AnyCancellable>()

    init(viewModel: MainViewModel, repository: any RepositoryProtocol) {
        self.viewModel = viewModel
        self.repository = repository
        collectionView = UICollectionView(frame: .zero, collectionViewLayout: Self.makeLayout())
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
        bindViewModel()
        viewModel.loadIfNeeded()
    }

    private func configureView() {
        title = "스터디"
        navigationItem.largeTitleDisplayMode = .always
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas

        collectionView.backgroundColor = .clear
        collectionView.alwaysBounceVertical = true
        collectionView.delegate = self
        collectionView.accessibilityIdentifier = "main.collection"
        collectionView.translatesAutoresizingMaskIntoConstraints = false

        stateView.translatesAutoresizingMaskIntoConstraints = false
        stateView.onAction = { [weak self] in
            self?.viewModel.retry()
        }

        view.addSubview(collectionView)
        view.addSubview(stateView)

        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        let registration = UICollectionView.CellRegistration<StudyCardCell, StudyListItemViewData> {
            cell, _, item in
            cell.configure(with: item)
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

    private func bindViewModel() {
        viewModel.statePublisher
            .removeDuplicates()
            .sink { [weak self] state in
                self?.render(state)
            }
            .store(in: &cancellables)
    }

    private func render(_ state: MainViewState) {
        switch state {
        case .loading:
            collectionView.isHidden = true
            stateView.render(.loading)
        case let .content(items):
            itemsByID = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            stateView.isHidden = true
            collectionView.isHidden = false
            var snapshot = NSDiffableDataSourceSnapshot<Section, Study.ID>()
            snapshot.appendSections([.main])
            snapshot.appendItems(items.map(\.id), toSection: .main)
            dataSource.apply(snapshot, animatingDifferences: view.window != nil)
        case .empty:
            collectionView.isHidden = true
            stateView.render(.empty)
        case .failure:
            collectionView.isHidden = true
            stateView.render(.failure)
        }
    }

    private static func makeLayout() -> UICollectionViewLayout {
        let itemSize = NSCollectionLayoutSize(
            widthDimension: .fractionalWidth(1),
            heightDimension: .estimated(176)
        )
        let item = NSCollectionLayoutItem(layoutSize: itemSize)
        let group = NSCollectionLayoutGroup.vertical(layoutSize: itemSize, subitems: [item])
        let section = NSCollectionLayoutSection(group: group)
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
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer { collectionView.deselectItem(at: indexPath, animated: true) }
        guard
            let studyID = dataSource.itemIdentifier(for: indexPath),
            viewModel.study(for: studyID) != nil
        else {
            return
        }

        let detailViewModel = DetailViewModel(studyID: studyID, repository: repository)
        let detailViewController = DetailViewController(viewModel: detailViewModel)
        navigationController?.pushViewController(detailViewController, animated: true)
    }
}

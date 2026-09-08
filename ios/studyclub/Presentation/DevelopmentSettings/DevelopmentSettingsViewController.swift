#if DEBUG
import UIKit

@MainActor
final class DevelopmentSettingsViewController: UIViewController {
    private let listView: UICollectionView = {
        var configuration = UICollectionLayoutListConfiguration(appearance: .insetGrouped)
        configuration.headerMode = .supplementary
        let layout = UICollectionViewCompositionalLayout.list(using: configuration)
        let view = UICollectionView(frame: .zero, collectionViewLayout: layout)
        view.backgroundColor = .clear
        view.accessibilityIdentifier = "development.list"
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private var dataSource: UICollectionViewDiffableDataSource<DevelopmentSettingSection.ID, DevelopmentSettingRow.ID>!
    private var rowsByID: [DevelopmentSettingRow.ID: DevelopmentSettingRow] = [:]

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        configureDataSource()
        updateViews(sections: [.init(id: .miscellaneous, rows: [])])
    }

    private func configureView() {
        title = "Development Settings"
        view.backgroundColor = AppTheme.Palette.canvas
        view.accessibilityIdentifier = "development.screen"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "닫기", style: .done, target: self, action: #selector(close)
        )
        navigationItem.rightBarButtonItem?.accessibilityIdentifier = "development.close"

        view.addSubview(listView)
        listView.delegate = self
        NSLayoutConstraint.activate([
            listView.topAnchor.constraint(equalTo: view.topAnchor),
            listView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            listView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            listView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    private func configureDataSource() {
        let cellRegistration = UICollectionView.CellRegistration<DevelopmentSettingCell, DevelopmentSettingRow> {
            [weak self] cell, _, row in
            cell.updateViews(with: row) { [weak self] isOn in
                self?.toggleChanged(id: row.id, isOn: isOn)
            }
        }
        dataSource = UICollectionViewDiffableDataSource(collectionView: listView) {
            [weak self] collectionView, indexPath, id in
            guard let row = self?.rowsByID[id] else { return nil }
            return collectionView.dequeueConfiguredReusableCell(using: cellRegistration, for: indexPath, item: row)
        }
        let headerRegistration = UICollectionView.SupplementaryRegistration<UICollectionViewListCell>(
            elementKind: UICollectionView.elementKindSectionHeader
        ) { [weak self] header, _, indexPath in
            guard let section = self?.dataSource.sectionIdentifier(for: indexPath.section) else { return }
            var content = header.defaultContentConfiguration()
            content.text = section.title
            header.contentConfiguration = content
            header.accessibilityTraits.insert(.header)
        }
        dataSource.supplementaryViewProvider = { collectionView, _, indexPath in
            collectionView.dequeueConfiguredReusableSupplementary(using: headerRegistration, for: indexPath)
        }
    }

    private func updateViews(sections: [DevelopmentSettingSection]) {
        let rows = sections.flatMap(\.rows)
        rowsByID = Dictionary(uniqueKeysWithValues: rows.map { ($0.id, $0) })
        var snapshot = NSDiffableDataSourceSnapshot<DevelopmentSettingSection.ID, DevelopmentSettingRow.ID>()
        for section in sections {
            snapshot.appendSections([section.id])
            snapshot.appendItems(section.rows.map(\.id), toSection: section.id)
        }
        let previousIDs = Set(dataSource.snapshot().itemIdentifiers)
        snapshot.reconfigureItems(snapshot.itemIdentifiers.filter(previousIDs.contains))
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    private func buttonSelected(id: DevelopmentSettingRow.ID) {
        // Actions are connected as development settings are added.
    }

    private func toggleChanged(id: DevelopmentSettingRow.ID, isOn: Bool) {
        // Toggle persistence is connected with the feature flag store.
    }

    @objc private func close() {
        dismiss(animated: true)
    }
}

extension DevelopmentSettingsViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        defer { collectionView.deselectItem(at: indexPath, animated: true) }
        guard let id = dataSource.itemIdentifier(for: indexPath), let row = rowsByID[id] else { return }
        switch row.kind {
        case .button: buttonSelected(id: id)
        case .toggle(let isOn): toggleChanged(id: id, isOn: !isOn)
        }
    }
}
#endif

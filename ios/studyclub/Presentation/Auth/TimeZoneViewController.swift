import UIKit

@MainActor
final class TimeZoneViewController: UITableViewController {
    private enum Section { case zones }
    private let zones = OnboardingViewModel.timeZoneIdentifiers
    private let selected: String
    private let onSelect: (String) -> Void
    private var dataSource: UITableViewDiffableDataSource<Section, String>!

    init(selected: String, onSelect: @escaping (String) -> Void) {
        self.selected = selected
        self.onSelect = onSelect
        super.init(style: .insetGrouped)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "시간대"
        navigationItem.largeTitleDisplayMode = .never
        tableView.backgroundColor = AppTheme.Palette.canvas
        tableView.tintColor = AppTheme.Palette.accent
        tableView.separatorColor = AppTheme.Palette.border
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "zone")
        dataSource = UITableViewDiffableDataSource(tableView: tableView) { [selected] tableView, indexPath, identifier in
            let cell = tableView.dequeueReusableCell(withIdentifier: "zone", for: indexPath)
            var configuration = cell.defaultContentConfiguration()
            configuration.text = identifier
            configuration.secondaryText = TimeZone(identifier: identifier)?.localizedName(for: .standard, locale: .current)
            configuration.textProperties.numberOfLines = 0
            configuration.textProperties.font = .preferredFont(forTextStyle: .body)
            configuration.textProperties.color = AppTheme.Palette.primaryText
            configuration.secondaryTextProperties.numberOfLines = 0
            configuration.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
            configuration.secondaryTextProperties.color = AppTheme.Palette.secondaryText
            cell.contentConfiguration = configuration
            cell.backgroundColor = AppTheme.Palette.surface
            cell.accessoryType = identifier == selected ? .checkmark : .none
            return cell
        }
        var snapshot = NSDiffableDataSourceSnapshot<Section, String>()
        snapshot.appendSections([.zones])
        snapshot.appendItems(zones)
        dataSource.apply(snapshot, animatingDifferences: false)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let indexPath = dataSource.indexPath(for: selected) {
            tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let identifier = dataSource.itemIdentifier(for: indexPath) else { return }
        onSelect(identifier)
        navigationController?.popViewController(animated: true)
    }
}

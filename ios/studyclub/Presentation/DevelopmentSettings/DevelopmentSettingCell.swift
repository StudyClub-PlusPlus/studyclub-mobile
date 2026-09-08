#if DEBUG
import UIKit

final class DevelopmentSettingCell: UICollectionViewListCell {
    private let toggle: UISwitch = {
        let view = UISwitch()
        view.onTintColor = AppTheme.Palette.accent
        return view
    }()
    private var onToggle: ((Bool) -> Void)?

    override init(frame: CGRect) {
        super.init(frame: frame)
        toggle.addTarget(self, action: #selector(toggleChanged), for: .valueChanged)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateViews(with row: DevelopmentSettingRow, onToggle: @escaping (Bool) -> Void) {
        self.onToggle = onToggle
        var content = defaultContentConfiguration()
        content.text = row.title
        content.textProperties.numberOfLines = 0
        accessibilityIdentifier = row.accessibilityIdentifier + ".row"

        switch row.kind {
        case .button(let value):
            content.secondaryText = value
            accessories = value == nil ? [] : [.disclosureIndicator()]
            isAccessibilityElement = true
            accessibilityLabel = row.title
            accessibilityValue = value
            accessibilityTraits = .button
        case .toggle(let isOn):
            toggle.setOn(isOn, animated: false)
            toggle.accessibilityLabel = row.title
            toggle.accessibilityIdentifier = row.accessibilityIdentifier
            accessories = [.customView(configuration: .init(
                customView: toggle,
                placement: .trailing(displayed: .always)
            ))]
            isAccessibilityElement = false
            accessibilityLabel = nil
            accessibilityValue = nil
            accessibilityTraits = []
        }
        contentConfiguration = content
    }

    @objc private func toggleChanged() {
        onToggle?(toggle.isOn)
    }
}
#endif

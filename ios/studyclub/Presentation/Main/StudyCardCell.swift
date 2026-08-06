import UIKit

final class StudyCardCell: UICollectionViewCell {
    private let categoryLabel = InsetLabel()
    private let statusLabel = UILabel()
    private let titleLabel = UILabel()
    private let summaryLabel = UILabel()
    private let memberImageView = UIImageView(image: UIImage(systemName: "person.2"))
    private let memberLabel = UILabel()
    private let disclosureImageView = UIImageView(image: UIImage(systemName: "chevron.right"))
    private let headerSpacer = UIView()
    private let headerStack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func updateConfiguration(using state: UICellConfigurationState) {
        super.updateConfiguration(using: state)
        contentView.backgroundColor = state.isHighlighted
            ? AppTheme.Palette.elevatedSurface
            : AppTheme.Palette.surface
        contentView.layer.borderColor = AppTheme.Palette.border
            .resolvedColor(with: traitCollection)
            .withAlphaComponent(0.35)
            .cgColor
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        updateHeaderLayout()
    }

    func configure(with item: StudyListItemViewData) {
        categoryLabel.text = item.category
        statusLabel.text = item.statusText
        titleLabel.text = item.title
        summaryLabel.text = item.summary
        memberLabel.text = item.memberText
        accessibilityIdentifier = "main.study.\(item.id)"
        accessibilityLabel = "\(item.title), \(item.category), \(item.memberText), \(item.statusText). \(item.summary)"
    }

    private func configureView() {
        contentView.layer.cornerRadius = AppTheme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)

        isAccessibilityElement = true
        accessibilityTraits = .button

        categoryLabel.font = .preferredFont(forTextStyle: .caption1)
        categoryLabel.adjustsFontForContentSizeCategory = true
        categoryLabel.textColor = AppTheme.Palette.accent
        categoryLabel.backgroundColor = AppTheme.Palette.accent.withAlphaComponent(0.10)
        categoryLabel.layer.cornerRadius = AppTheme.Radius.control
        categoryLabel.layer.cornerCurve = .continuous
        categoryLabel.clipsToBounds = true
        categoryLabel.numberOfLines = 0

        statusLabel.font = .preferredFont(forTextStyle: .caption1)
        statusLabel.adjustsFontForContentSizeCategory = true
        statusLabel.textColor = AppTheme.Palette.secondaryText
        statusLabel.numberOfLines = 0

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Palette.primaryText
        titleLabel.numberOfLines = 0

        summaryLabel.font = .preferredFont(forTextStyle: .subheadline)
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = AppTheme.Palette.secondaryText
        summaryLabel.numberOfLines = 0

        memberImageView.tintColor = AppTheme.Palette.secondaryText
        memberImageView.setContentHuggingPriority(.required, for: .horizontal)
        memberImageView.isAccessibilityElement = false

        memberLabel.font = .preferredFont(forTextStyle: .caption1)
        memberLabel.adjustsFontForContentSizeCategory = true
        memberLabel.textColor = AppTheme.Palette.secondaryText

        disclosureImageView.tintColor = AppTheme.Palette.secondaryText
        disclosureImageView.setContentHuggingPriority(.required, for: .horizontal)
        disclosureImageView.isAccessibilityElement = false

        headerStack.addArrangedSubview(categoryLabel)
        headerStack.addArrangedSubview(headerSpacer)
        headerStack.addArrangedSubview(statusLabel)
        headerStack.axis = .horizontal
        headerStack.alignment = .center
        headerStack.spacing = AppTheme.Spacing.small

        let footerSpacer = UIView()
        let footerStack = UIStackView(arrangedSubviews: [memberImageView, memberLabel, footerSpacer, disclosureImageView])
        footerStack.axis = .horizontal
        footerStack.alignment = .center
        footerStack.spacing = AppTheme.Spacing.small

        let contentStack = UIStackView(arrangedSubviews: [headerStack, titleLabel, summaryLabel, footerStack])
        contentStack.axis = .vertical
        contentStack.spacing = AppTheme.Spacing.medium
        contentStack.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(contentStack)

        NSLayoutConstraint.activate([
            memberImageView.widthAnchor.constraint(equalToConstant: 16),
            memberImageView.heightAnchor.constraint(equalToConstant: 16),
            disclosureImageView.widthAnchor.constraint(equalToConstant: 14),
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.regular),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Spacing.regular),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.regular),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Spacing.regular)
        ])
    }

    private func updateHeaderLayout() {
        let usesAccessibilityLayout = traitCollection.preferredContentSizeCategory.isAccessibilityCategory
        let desiredAxis: NSLayoutConstraint.Axis = usesAccessibilityLayout ? .vertical : .horizontal
        guard headerStack.axis != desiredAxis else { return }

        headerStack.axis = desiredAxis
        headerStack.alignment = usesAccessibilityLayout ? .leading : .center
        headerSpacer.isHidden = usesAccessibilityLayout
    }
}

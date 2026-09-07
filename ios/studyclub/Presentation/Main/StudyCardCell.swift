import UIKit

final class StudyCardCell: UICollectionViewCell {
    private let categoryLabel = {
        let view = InsetLabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = AppTheme.Palette.accent
        view.backgroundColor = AppTheme.Palette.accent.withAlphaComponent(0.10)
        view.layer.cornerRadius = AppTheme.Radius.control
        view.layer.cornerCurve = .continuous
        view.clipsToBounds = true
        view.numberOfLines = 0
        return view
    }()
    private let statusLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        return view
    }()
    private let titleLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .headline)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = AppTheme.Palette.primaryText
        view.numberOfLines = 0
        return view
    }()
    private let summaryLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        return view
    }()
    private let memberImageView = {
        let view = UIImageView(image: UIImage(systemName: "person.2"))
        view.tintColor = AppTheme.Palette.secondaryText
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.isAccessibilityElement = false
        return view
    }()
    private let memberLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.adjustsFontForContentSizeCategory = true
        view.textColor = AppTheme.Palette.secondaryText
        return view
    }()
    private let disclosureImageView = {
        let view = UIImageView(image: UIImage(systemName: "chevron.right"))
        view.tintColor = AppTheme.Palette.secondaryText
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.isAccessibilityElement = false
        return view
    }()
    private let footerSpacer = UIView()
    private let footerStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = AppTheme.Spacing.small
        return stack
    }()
    private let contentStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = AppTheme.Spacing.medium
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()
    private let headerSpacer = UIView()
    private let headerStack = {
        let view = UIStackView()
        view.axis = .horizontal
        view.alignment = .center
        view.spacing = AppTheme.Spacing.small
        return view
    }()

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

    func updateViews(with item: StudyListItemViewData) {
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

        contentView.addSubview(contentStack)
        [headerStack, titleLabel, summaryLabel, footerStack].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.regular),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Spacing.regular),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.regular),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Spacing.regular)
        ])

        headerStack.addArrangedSubview(categoryLabel)
        headerStack.addArrangedSubview(headerSpacer)
        headerStack.addArrangedSubview(statusLabel)

        footerStack.addArrangedSubview(memberImageView)
        NSLayoutConstraint.activate([
            memberImageView.widthAnchor.constraint(equalToConstant: 16),
            memberImageView.heightAnchor.constraint(equalToConstant: 16)
        ])

        footerStack.addArrangedSubview(memberLabel)
        footerStack.addArrangedSubview(footerSpacer)

        footerStack.addArrangedSubview(disclosureImageView)
        disclosureImageView.widthAnchor.constraint(equalToConstant: 14).isActive = true
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

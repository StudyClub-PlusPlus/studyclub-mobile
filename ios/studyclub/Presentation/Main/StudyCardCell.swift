import UIKit

final class StudyCardCell: UICollectionViewCell {
    private let metadataLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let titleLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .headline)
        view.textColor = AppTheme.Palette.primaryText
        view.numberOfLines = 0
        return view
    }()
    private let summaryLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 2
        return view
    }()
    private let memberImageView = {
        let view = UIImageView(image: UIImage(systemName: "person.2"))
        view.tintColor = AppTheme.Palette.secondaryText
        view.setContentHuggingPriority(.required, for: .horizontal)
        return view
    }()
    private let memberLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        return view
    }()
    private let disclosureImageView = {
        let view = UIImageView(image: UIImage(systemName: "chevron.right"))
        view.tintColor = AppTheme.Palette.secondaryText
        view.setContentHuggingPriority(.required, for: .horizontal)
        view.setContentCompressionResistancePriority(.required, for: .horizontal)
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
            .cgColor
    }

    func updateViews(with item: StudyCardCellViewModel) {
        metadataLabel.text = [item.category, item.statusText]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        metadataLabel.isHidden = metadataLabel.text?.isEmpty ?? true
        titleLabel.text = item.title
        summaryLabel.text = item.summary
        summaryLabel.isHidden = item.summary.isEmpty
        contentStack.setCustomSpacing(
            item.summary.isEmpty ? AppTheme.Spacing.regular : AppTheme.Spacing.small,
            after: titleLabel
        )
        memberLabel.text = item.memberText
    }

    private func configureView() {
        contentView.layer.cornerRadius = AppTheme.Radius.card
        contentView.layer.cornerCurve = .continuous
        contentView.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)

        contentView.addSubview(contentStack)
        [metadataLabel, titleLabel, summaryLabel, footerStack].forEach(contentStack.addArrangedSubview)
        contentStack.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)
        contentStack.setCustomSpacing(AppTheme.Spacing.regular, after: summaryLabel)
        NSLayoutConstraint.activate([
            contentStack.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.large),
            contentStack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Spacing.large),
            contentStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.large),
            contentStack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Spacing.large)
        ])

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
}

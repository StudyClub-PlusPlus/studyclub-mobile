import UIKit

@MainActor
final class DetailViewController: UIViewController {
    private let viewModel: DetailViewModel
    private let scrollView = UIScrollView()
    private let contentView = UIView()

    init(viewModel: DetailViewModel) {
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
    }

    private func configureView() {
        let state = viewModel.state
        title = "스터디 상세"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.Palette.canvas
        view.accessibilityIdentifier = "detail.screen"

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(contentView)

        let categoryLabel = InsetLabel()
        categoryLabel.text = state.category
        categoryLabel.font = .preferredFont(forTextStyle: .caption1)
        categoryLabel.adjustsFontForContentSizeCategory = true
        categoryLabel.textColor = AppTheme.Palette.accent
        categoryLabel.backgroundColor = AppTheme.Palette.accent.withAlphaComponent(0.10)
        categoryLabel.layer.cornerRadius = AppTheme.Radius.control
        categoryLabel.layer.cornerCurve = .continuous
        categoryLabel.clipsToBounds = true
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false

        let categoryContainer = UIView()
        categoryContainer.addSubview(categoryLabel)
        NSLayoutConstraint.activate([
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: categoryContainer.trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor)
        ])

        let titleLabel = UILabel()
        titleLabel.text = state.title
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Palette.primaryText
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "detail.title"

        let metadataLabel = UILabel()
        metadataLabel.text = "\(state.memberText)  ·  \(state.statusText)"
        metadataLabel.font = .preferredFont(forTextStyle: .subheadline)
        metadataLabel.adjustsFontForContentSizeCategory = true
        metadataLabel.textColor = AppTheme.Palette.secondaryText
        metadataLabel.numberOfLines = 0

        let summaryLabel = UILabel()
        summaryLabel.text = state.summary
        summaryLabel.font = .preferredFont(forTextStyle: .body)
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = AppTheme.Palette.primaryText
        summaryLabel.numberOfLines = 0

        let divider = UIView()
        divider.backgroundColor = AppTheme.Palette.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)).isActive = true

        let topicsTitleLabel = UILabel()
        topicsTitleLabel.text = "이 스터디에서 다룰 내용"
        topicsTitleLabel.font = .preferredFont(forTextStyle: .headline)
        topicsTitleLabel.adjustsFontForContentSizeCategory = true
        topicsTitleLabel.textColor = AppTheme.Palette.primaryText
        topicsTitleLabel.numberOfLines = 0

        let topicsStack = UIStackView()
        topicsStack.axis = .vertical
        topicsStack.spacing = AppTheme.Spacing.medium
        for topic in state.topics {
            topicsStack.addArrangedSubview(makeTopicRow(text: topic))
        }

        let stackView = UIStackView(arrangedSubviews: [
            categoryContainer,
            titleLabel,
            metadataLabel,
            summaryLabel,
            divider,
            topicsTitleLabel,
            topicsStack
        ])
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.spacing = AppTheme.Spacing.regular
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: categoryContainer)
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: summaryLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: divider)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: AppTheme.Spacing.xLarge),
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: AppTheme.Spacing.large),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -AppTheme.Spacing.large),
            stackView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -AppTheme.Spacing.xxLarge)
        ])
    }

    private func makeTopicRow(text: String) -> UIView {
        let imageView = UIImageView(image: UIImage(systemName: "checkmark.circle.fill"))
        imageView.tintColor = AppTheme.Palette.accent
        imageView.setContentHuggingPriority(.required, for: .horizontal)
        imageView.isAccessibilityElement = false

        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .body)
        label.adjustsFontForContentSizeCategory = true
        label.textColor = AppTheme.Palette.primaryText
        label.numberOfLines = 0

        let stackView = UIStackView(arrangedSubviews: [imageView, label])
        stackView.axis = .horizontal
        stackView.alignment = .firstBaseline
        stackView.spacing = AppTheme.Spacing.medium
        return stackView
    }
}

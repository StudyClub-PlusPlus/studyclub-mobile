import Combine
import UIKit

@MainActor
final class DetailViewController: UIViewController {
    private let viewModel: DetailViewModel
    private var cancellables = Set<AnyCancellable>()
    private let stateView: ContentStateView = {
        let view = ContentStateView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.alwaysBounceVertical = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let contentView: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let categoryContainer = UIView()
    private let categoryLabel: InsetLabel = {
        let categoryLabel = InsetLabel()
        categoryLabel.font = .preferredFont(forTextStyle: .caption1)
        categoryLabel.adjustsFontForContentSizeCategory = true
        categoryLabel.textColor = AppTheme.Palette.accent
        categoryLabel.backgroundColor = AppTheme.Palette.accent.withAlphaComponent(0.10)
        categoryLabel.layer.cornerRadius = AppTheme.Radius.control
        categoryLabel.layer.cornerCurve = .continuous
        categoryLabel.clipsToBounds = true
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        return categoryLabel
    }()

    private let titleLabel: UILabel = {
        let titleLabel = UILabel()
        titleLabel.font = .preferredFont(forTextStyle: .title1)
        titleLabel.adjustsFontForContentSizeCategory = true
        titleLabel.textColor = AppTheme.Palette.primaryText
        titleLabel.numberOfLines = 0
        titleLabel.accessibilityIdentifier = "detail.title"
        return titleLabel
    }()

    private let metadataLabel: UILabel = {
        let metadataLabel = UILabel()
        metadataLabel.font = .preferredFont(forTextStyle: .subheadline)
        metadataLabel.adjustsFontForContentSizeCategory = true
        metadataLabel.textColor = AppTheme.Palette.secondaryText
        metadataLabel.numberOfLines = 0
        return metadataLabel
    }()

    private let summaryLabel: UILabel = {
        let summaryLabel = UILabel()
        summaryLabel.font = .preferredFont(forTextStyle: .body)
        summaryLabel.adjustsFontForContentSizeCategory = true
        summaryLabel.textColor = AppTheme.Palette.primaryText
        summaryLabel.numberOfLines = 0
        return summaryLabel
    }()

    private let divider: UIView = {
        let divider = UIView()
        divider.backgroundColor = AppTheme.Palette.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        return divider
    }()

    private let topicsTitleLabel: UILabel = {
        let topicsTitleLabel = UILabel()
        topicsTitleLabel.text = "이 스터디에서 다룰 내용"
        topicsTitleLabel.font = .preferredFont(forTextStyle: .headline)
        topicsTitleLabel.adjustsFontForContentSizeCategory = true
        topicsTitleLabel.textColor = AppTheme.Palette.primaryText
        topicsTitleLabel.numberOfLines = 0
        return topicsTitleLabel
    }()

    private let topicsStack: UIStackView = {
        let topicsStack = UIStackView()
        topicsStack.axis = .vertical
        topicsStack.spacing = AppTheme.Spacing.medium

        return topicsStack
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .fill
        stack.spacing = AppTheme.Spacing.regular
        stack.translatesAutoresizingMaskIntoConstraints = false
        return stack
    }()

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
        bindViewModel()
    }

    private func configureView() {
        title = "스터디 상세"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.Palette.canvas
        view.accessibilityIdentifier = "detail.screen"

        view.addSubview(scrollView)
        view.addSubview(stateView)
        scrollView.addSubview(contentView)
        contentView.addSubview(stackView)
        categoryContainer.addSubview(categoryLabel)
        [categoryContainer, titleLabel, metadataLabel, summaryLabel,
         divider, topicsTitleLabel, topicsStack].forEach(stackView.addArrangedSubview)

        stackView.setCustomSpacing(AppTheme.Spacing.small, after: categoryContainer)
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: summaryLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: divider)
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: categoryContainer.trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor),
            divider.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1))
        ])
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

    private func bindViewModel() {
        viewModel.statePublisher
            .sink { [weak self] state in
                guard let self else { return }
                self.scrollView.isHidden = state != .content
                switch state {
                case .loading:
                    self.stateView.updateViews(.loading, context: .detail)
                case .failure:
                    self.stateView.updateViews(.failure, context: .detail)
                case .content:
                    self.stateView.isHidden = true
                    self.updateViews()
                }
            }
            .store(in: &cancellables)
    }

    private func updateViews() {
        categoryLabel.text = viewModel.category
        titleLabel.text = viewModel.title
        metadataLabel.text = "\(viewModel.memberText)  ·  \(viewModel.statusText)"
        summaryLabel.text = viewModel.summary
        topicsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for topic in viewModel.topics {
            topicsStack.addArrangedSubview(makeTopicRow(text: topic))
        }
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

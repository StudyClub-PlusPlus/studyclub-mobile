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
        titleLabel.textColor = AppTheme.Palette.primaryText
        titleLabel.numberOfLines = 0
        return titleLabel
    }()

    private let metadataLabel: UILabel = {
        let metadataLabel = UILabel()
        metadataLabel.font = .preferredFont(forTextStyle: .subheadline)
        metadataLabel.textColor = AppTheme.Palette.secondaryText
        metadataLabel.numberOfLines = 0
        return metadataLabel
    }()

    private let scheduleLabel: UILabel = {
        let scheduleLabel = UILabel()
        scheduleLabel.font = .preferredFont(forTextStyle: .subheadline)
        scheduleLabel.textColor = AppTheme.Palette.secondaryText
        scheduleLabel.numberOfLines = 0
        return scheduleLabel
    }()

    private let descriptionLabel: UILabel = {
        let descriptionLabel = UILabel()
        descriptionLabel.font = .preferredFont(forTextStyle: .body)
        descriptionLabel.textColor = AppTheme.Palette.primaryText
        descriptionLabel.numberOfLines = 0
        return descriptionLabel
    }()

    private let divider: UIView = {
        let divider = UIView()
        divider.backgroundColor = AppTheme.Palette.border
        divider.translatesAutoresizingMaskIntoConstraints = false
        return divider
    }()

    private let curriculumTitleLabel: UILabel = {
        let curriculumTitleLabel = UILabel()
        curriculumTitleLabel.text = "커리큘럼"
        curriculumTitleLabel.font = .preferredFont(forTextStyle: .headline)
        curriculumTitleLabel.textColor = AppTheme.Palette.primaryText
        curriculumTitleLabel.numberOfLines = 0
        return curriculumTitleLabel
    }()

    private let curriculumLabel: UILabel = {
        let curriculumLabel = UILabel()
        curriculumLabel.font = .preferredFont(forTextStyle: .body)
        curriculumLabel.textColor = AppTheme.Palette.primaryText
        curriculumLabel.numberOfLines = 0
        return curriculumLabel
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

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        view.addSubview(stateView)
        NSLayoutConstraint.activate([
            stateView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            stateView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stateView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stateView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])

        scrollView.addSubview(contentView)
        NSLayoutConstraint.activate([
            contentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            contentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            contentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            contentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            contentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        contentView.addSubview(stackView)
        stackView.addArrangedSubview(categoryContainer)
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: categoryContainer)
        categoryContainer.addSubview(categoryLabel)
        NSLayoutConstraint.activate([
            categoryLabel.topAnchor.constraint(equalTo: categoryContainer.topAnchor),
            categoryLabel.leadingAnchor.constraint(equalTo: categoryContainer.leadingAnchor),
            categoryLabel.trailingAnchor.constraint(lessThanOrEqualTo: categoryContainer.trailingAnchor),
            categoryLabel.bottomAnchor.constraint(equalTo: categoryContainer.bottomAnchor)
        ])

        stackView.addArrangedSubview(titleLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: titleLabel)

        stackView.addArrangedSubview(metadataLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.small, after: metadataLabel)

        stackView.addArrangedSubview(scheduleLabel)

        stackView.addArrangedSubview(descriptionLabel)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: descriptionLabel)

        stackView.addArrangedSubview(divider)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: divider)
        divider.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)).isActive = true

        stackView.addArrangedSubview(curriculumTitleLabel)
        stackView.addArrangedSubview(curriculumLabel)
        NSLayoutConstraint.activate([
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
                case .empty:
                    self.stateView.updateViews(.empty, context: .detail)
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
        metadataLabel.text = "\(viewModel.metadataText)  ·  \(viewModel.recruitStatusText)"
        scheduleLabel.text = viewModel.scheduleText
        scheduleLabel.isHidden = viewModel.scheduleText.isEmpty
        descriptionLabel.text = viewModel.descriptionText
        descriptionLabel.isHidden = viewModel.descriptionText.isEmpty
        curriculumTitleLabel.isHidden = viewModel.curriculum.isEmpty
        curriculumLabel.text = viewModel.curriculum
        curriculumLabel.isHidden = viewModel.curriculum.isEmpty
    }
}

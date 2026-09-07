import UIKit

final class ContentStateView: UIView {
    enum Context {
        case main
        case detail
    }
    enum State {
        case loading
        case empty
        case failure
    }

    var onAction: (() -> Void)?

    private let activityIndicator = UIActivityIndicatorView(style: .medium)
    private let imageView = UIImageView()
    private let titleLabel = UILabel()
    private let messageLabel = UILabel()
    private let actionButton = UIButton(type: .system)
    private let scrollView = UIScrollView()
    private let scrollContentView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        configureView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func render(_ state: State, context: Context = .main) {
        isHidden = false
        activityIndicator.stopAnimating()
        imageView.isHidden = false
        actionButton.isHidden = false

        switch state {
        case .loading:
            accessibilityIdentifier = "main.state.loading"
            activityIndicator.startAnimating()
            imageView.isHidden = true
            titleLabel.text = "스터디를 불러오는 중이에요"
            messageLabel.text = "잠시만 기다려 주세요."
            actionButton.isHidden = true
        case .empty:
            accessibilityIdentifier = "main.state.empty"
            imageView.image = UIImage(systemName: "books.vertical")
            imageView.tintColor = AppTheme.Palette.secondaryText
            titleLabel.text = "아직 열린 스터디가 없어요"
            messageLabel.text = "새로운 모임이 생겼는지 다시 확인해 보세요."
            actionButton.configuration?.title = "새로고침"
            actionButton.accessibilityLabel = "스터디 목록 새로고침"
        case .failure:
            accessibilityIdentifier = "main.state.failure"
            imageView.image = UIImage(systemName: "exclamationmark.circle")
            imageView.tintColor = AppTheme.Palette.error
            titleLabel.text = "목록을 불러오지 못했어요"
            messageLabel.text = "연결을 확인한 뒤 다시 시도해 주세요."
            actionButton.configuration?.title = "다시 시도"
            actionButton.accessibilityLabel = "스터디 목록 다시 시도"
        }
        let prefix = context == .detail ? "detail" : "main"
        actionButton.accessibilityIdentifier = "\(prefix).state.action"
        activityIndicator.accessibilityIdentifier = "\(prefix).loading.indicator"
        if context == .detail {
            switch state {
            case .loading:
                accessibilityIdentifier = "detail.state.loading"
                titleLabel.text = "스터디 상세를 불러오는 중이에요"
            case .failure:
                accessibilityIdentifier = "detail.state.failure"
                titleLabel.text = "상세 정보를 불러오지 못했어요"
                actionButton.accessibilityLabel = "스터디 상세 다시 시도"
            case .empty:
                break
            }
        }
    }

    private func configureView() {
        backgroundColor = AppTheme.Palette.canvas

        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = AppTheme.Palette.accent
        activityIndicator.accessibilityIdentifier = "main.loading.indicator"

        imageView.contentMode = .scaleAspectFit
        imageView.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        imageView.isAccessibilityElement = false

        titleLabel.font = .preferredFont(forTextStyle: .headline)
        titleLabel.textColor = AppTheme.Palette.primaryText
        titleLabel.textAlignment = .center
        titleLabel.numberOfLines = 0
        titleLabel.adjustsFontForContentSizeCategory = true

        messageLabel.font = .preferredFont(forTextStyle: .subheadline)
        messageLabel.textColor = AppTheme.Palette.secondaryText
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.adjustsFontForContentSizeCategory = true

        var buttonConfiguration = UIButton.Configuration.filled()
        buttonConfiguration.baseBackgroundColor = AppTheme.Palette.accent
        buttonConfiguration.baseForegroundColor = .white
        buttonConfiguration.cornerStyle = .medium
        buttonConfiguration.contentInsets = NSDirectionalEdgeInsets(
            top: AppTheme.Spacing.medium,
            leading: AppTheme.Spacing.regular,
            bottom: AppTheme.Spacing.medium,
            trailing: AppTheme.Spacing.regular
        )
        actionButton.configuration = buttonConfiguration
        actionButton.accessibilityIdentifier = "main.state.action"
        actionButton.addAction(UIAction { [weak self] _ in
            self?.onAction?()
        }, for: .touchUpInside)

        let stackView = UIStackView(arrangedSubviews: [
            activityIndicator,
            imageView,
            titleLabel,
            messageLabel,
            actionButton
        ])
        stackView.axis = .vertical
        stackView.alignment = .center
        stackView.spacing = AppTheme.Spacing.medium
        stackView.setCustomSpacing(AppTheme.Spacing.large, after: imageView)
        stackView.setCustomSpacing(AppTheme.Spacing.xLarge, after: messageLabel)
        stackView.translatesAutoresizingMaskIntoConstraints = false

        scrollView.alwaysBounceVertical = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollContentView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        scrollContentView.addSubview(stackView)

        let centerYConstraint = stackView.centerYAnchor.constraint(equalTo: scrollContentView.centerYAnchor)
        centerYConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 44),
            imageView.heightAnchor.constraint(equalToConstant: 44),
            actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44),
            actionButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 120),
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
            scrollContentView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            scrollContentView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            scrollContentView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            scrollContentView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            scrollContentView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            scrollContentView.heightAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.heightAnchor),
            centerYConstraint,
            stackView.topAnchor.constraint(greaterThanOrEqualTo: scrollContentView.topAnchor, constant: AppTheme.Spacing.xLarge),
            stackView.bottomAnchor.constraint(lessThanOrEqualTo: scrollContentView.bottomAnchor, constant: -AppTheme.Spacing.xLarge),
            stackView.leadingAnchor.constraint(greaterThanOrEqualTo: scrollContentView.leadingAnchor, constant: AppTheme.Spacing.xLarge),
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: scrollContentView.trailingAnchor, constant: -AppTheme.Spacing.xLarge),
            stackView.centerXAnchor.constraint(equalTo: scrollContentView.centerXAnchor)
        ])
    }
}

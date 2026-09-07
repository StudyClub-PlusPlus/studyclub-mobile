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

    private let activityIndicator = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.color = AppTheme.Palette.accent
        view.accessibilityIdentifier = "main.loading.indicator"
        return view
    }()
    private let imageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.preferredSymbolConfiguration = UIImage.SymbolConfiguration(pointSize: 32, weight: .regular)
        view.isAccessibilityElement = false
        return view
    }()
    private let titleLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .headline)
        view.textColor = AppTheme.Palette.primaryText
        view.textAlignment = .center
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }()
    private let messageLabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.textColor = AppTheme.Palette.secondaryText
        view.textAlignment = .center
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }()
    private let scrollView = {
        let view = UIScrollView()
        view.alwaysBounceVertical = true
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let scrollContentView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    private let stackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.alignment = .center
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

    func updateViews(_ state: State, context: Context = .main) {
        isHidden = false
        activityIndicator.stopAnimating()
        imageView.isHidden = false

        switch state {
        case .loading:
            accessibilityIdentifier = "main.state.loading"
            activityIndicator.startAnimating()
            imageView.isHidden = true
            titleLabel.text = "스터디를 불러오는 중이에요"
            messageLabel.text = "잠시만 기다려 주세요."
        case .empty:
            accessibilityIdentifier = "main.state.empty"
            imageView.image = UIImage(systemName: "books.vertical")
            imageView.tintColor = AppTheme.Palette.secondaryText
            titleLabel.text = "아직 열린 스터디가 없어요"
            messageLabel.text = "등록된 스터디가 없어요."
        case .failure:
            accessibilityIdentifier = "main.state.failure"
            imageView.image = UIImage(systemName: "exclamationmark.circle")
            imageView.tintColor = AppTheme.Palette.error
            titleLabel.text = "목록을 불러오지 못했어요"
            messageLabel.text = "지금은 목록을 확인할 수 없어요."
        }
        let prefix = context == .detail ? "detail" : "main"
        activityIndicator.accessibilityIdentifier = "\(prefix).loading.indicator"
        if context == .detail {
            switch state {
            case .loading:
                accessibilityIdentifier = "detail.state.loading"
                titleLabel.text = "스터디 상세를 불러오는 중이에요"
            case .failure:
                accessibilityIdentifier = "detail.state.failure"
                titleLabel.text = "상세 정보를 불러오지 못했어요"
                messageLabel.text = "이전 화면으로 돌아가 주세요."
            case .empty:
                break
            }
        }
    }

    private func configureView() {
        backgroundColor = AppTheme.Palette.canvas





        [activityIndicator, imageView, titleLabel, messageLabel].forEach(stackView.addArrangedSubview)
        stackView.setCustomSpacing(AppTheme.Spacing.large, after: imageView)

        addSubview(scrollView)
        scrollView.addSubview(scrollContentView)
        scrollContentView.addSubview(stackView)

        let centerYConstraint = stackView.centerYAnchor.constraint(equalTo: scrollContentView.centerYAnchor)
        centerYConstraint.priority = .defaultHigh

        NSLayoutConstraint.activate([
            imageView.widthAnchor.constraint(equalToConstant: 44),
            imageView.heightAnchor.constraint(equalToConstant: 44),
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

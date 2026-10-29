import Combine
import UIKit

@MainActor
final class LoginViewController: UIViewController {
    private let viewModel: LoginViewModel
    private let onGoogleSignIn: (LoginViewController) -> Void
    private let onAppleSignIn: () -> Void
    private let onCancelSignIn: () -> Void
    private let onRetryCleanup: () -> Void
    private let onClose: () -> Void
    private var subscriptions = Set<AnyCancellable>()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let content: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.xLarge
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let heading: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = "스터디클럽에 로그인"
        view.font = .preferredFont(forTextStyle: .title2)
        view.textColor = AppTheme.Palette.primaryText
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }()
    private let introduction: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = "Google 계정으로 스터디클럽에 로그인하세요."
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }()
    private let providerGroup: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.medium
        view.isLayoutMarginsRelativeArrangement = true
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: AppTheme.Spacing.small, leading: AppTheme.Spacing.regular,
            bottom: AppTheme.Spacing.small, trailing: AppTheme.Spacing.regular
        )
        view.backgroundColor = AppTheme.Palette.surface
        view.layer.cornerRadius = AppTheme.Radius.card
        view.clipsToBounds = true
        return view
    }()
    private let statusRow: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alignment = .center
        view.spacing = AppTheme.Spacing.medium
        return view
    }()
    /// Custom buttons that follow both brands' rules (official Google "G" from the SDK, Apple logo,
    /// brand colors) so the two share one height, radius, type and icon position.
    private let googleButton = LoginViewController.providerButton(title: "Google로 계속하기", image: UIImage(named: "GoogleLogo"))
    private let appleButton = LoginViewController.providerButton(title: "Apple로 계속하기", image: UIImage(systemName: "apple.logo"))
    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.hidesWhenStopped = true
        view.color = AppTheme.Palette.accent
        return view
    }()
    private let statusLabel: UILabel = {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.font = .preferredFont(forTextStyle: .subheadline)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }()
    private let cancelButton: UIButton = {
        let view = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "로그인 취소"
        view.configuration = configuration
        view.tintColor = AppTheme.Palette.accent
        view.contentHorizontalAlignment = .leading
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let cleanupRetryButton: UIButton = {
        let view = UIButton(type: .system)
        var configuration = UIButton.Configuration.plain()
        configuration.title = "정리 다시 시도"
        view.configuration = configuration
        view.tintColor = AppTheme.Palette.accent
        view.contentHorizontalAlignment = .leading
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    convenience init(
        onGoogleSignIn: @escaping (LoginViewController) -> Void,
        onAppleSignIn: @escaping () -> Void = {},
        onCancelSignIn: @escaping () -> Void,
        onRetryCleanup: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.init(
            viewModel: LoginViewModel(),
            onGoogleSignIn: onGoogleSignIn,
            onAppleSignIn: onAppleSignIn,
            onCancelSignIn: onCancelSignIn,
            onRetryCleanup: onRetryCleanup,
            onClose: onClose
        )
    }

    init(
        viewModel: LoginViewModel,
        onGoogleSignIn: @escaping (LoginViewController) -> Void,
        onAppleSignIn: @escaping () -> Void = {},
        onCancelSignIn: @escaping () -> Void,
        onRetryCleanup: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onGoogleSignIn = onGoogleSignIn
        self.onAppleSignIn = onAppleSignIn
        self.onCancelSignIn = onCancelSignIn
        self.onRetryCleanup = onRetryCleanup
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        viewModel.statePublisher
            .sink { [weak self] _ in self?.updateViews() }
            .store(in: &subscriptions)
        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (self: LoginViewController, _) in
            self.updateProviderStyle()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        providerGroup.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        providerGroup.layer.borderColor = AppTheme.Palette.border.resolvedColor(with: traitCollection).cgColor
        updateProviderStyle()
    }

    private func configureView() {
        title = "로그인"
        view.backgroundColor = AppTheme.Palette.canvas
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "닫기", style: .plain, target: self, action: #selector(requestClose)
        )
        // All dismissal must reach the owner, including while provider work is pending.
        isModalInPresentation = true
        navigationController?.isModalInPresentation = true
        navigationController?.navigationBar.tintColor = AppTheme.Palette.accent

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor)
        ])

        scrollView.addSubview(content)
        let equalWidth = content.widthAnchor.constraint(
            equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * AppTheme.Spacing.large
        )
        equalWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.xLarge),
            content.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.large),
            content.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.large),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xLarge),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            equalWidth
        ])

        content.addArrangedSubview(heading)
        content.setCustomSpacing(AppTheme.Spacing.medium, after: heading)
        content.addArrangedSubview(introduction)
        introduction.text = viewModel.introduction

        content.addArrangedSubview(providerGroup)
        for button in [googleButton, appleButton] {
            providerGroup.addArrangedSubview(button)
            button.heightAnchor.constraint(equalToConstant: 50).isActive = true
        }
        googleButton.addTarget(self, action: #selector(requestGoogleSignIn), for: .touchUpInside)
        appleButton.addTarget(self, action: #selector(requestAppleSignIn), for: .touchUpInside)

        providerGroup.addArrangedSubview(statusRow)
        statusRow.addArrangedSubview(spinner)
        spinner.setContentHuggingPriority(.required, for: .horizontal)
        spinner.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusRow.addArrangedSubview(statusLabel)
        providerGroup.addArrangedSubview(cancelButton)
        cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        cancelButton.addTarget(self, action: #selector(requestCancellation), for: .touchUpInside)
        providerGroup.addArrangedSubview(cleanupRetryButton)
        cleanupRetryButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        cleanupRetryButton.addTarget(self, action: #selector(requestCleanupRetry), for: .touchUpInside)
    }

    private func updateViews() {
        let signingIn = viewModel.state == .signingIn
        let cleaning = viewModel.state == .cancelling
        for button in [googleButton, appleButton] {
            button.isEnabled = viewModel.canSignIn
            button.alpha = viewModel.canSignIn ? 1 : 0.5
        }
        statusLabel.text = viewModel.statusMessage
        statusRow.isHidden = viewModel.statusMessage == nil
        statusLabel.textColor = [.failure, .cleanupFailed, .emailInUse].contains(viewModel.state)
            ? AppTheme.Palette.error : AppTheme.Palette.secondaryText
        spinner.isHidden = !(signingIn || cleaning)
        if signingIn || cleaning { spinner.startAnimating() } else { spinner.stopAnimating() }
        cancelButton.isHidden = !signingIn
        cleanupRetryButton.isHidden = viewModel.state != .cleanupFailed
    }

    /// Brand colors follow the surface behind the buttons, not the system appearance: the design
    /// system keeps a light surface in dark mode. Light surface: white Google, black Apple.
    private func updateProviderStyle() {
        var white: CGFloat = 1
        AppTheme.Palette.surface.resolvedColor(with: traitCollection).getWhite(&white, alpha: nil)
        let dark = white < 0.5
        let google = (foreground: UIColor(white: dark ? 0.89 : 0.12, alpha: 1),
                      background: UIColor(white: dark ? 0.075 : 1, alpha: 1))
        let apple = (foreground: dark ? UIColor.black : .white, background: dark ? UIColor.white : .black)
        googleButton.configuration?.baseForegroundColor = google.foreground
        googleButton.configuration?.baseBackgroundColor = google.background
        googleButton.layer.borderWidth = 1
        googleButton.layer.cornerRadius = AppTheme.Radius.control
        googleButton.layer.borderColor = UIColor(white: dark ? 0.56 : 0.46, alpha: 1).cgColor
        appleButton.configuration?.baseForegroundColor = apple.foreground
        appleButton.configuration?.baseBackgroundColor = apple.background
    }

    private static func providerButton(title: String, image: UIImage?) -> UIButton {
        var configuration = UIButton.Configuration.filled()
        configuration.title = title
        // The Google "G" keeps its colors; the Apple symbol takes the title color.
        configuration.image = image?.withRenderingMode(image?.isSymbolImage == true ? .alwaysTemplate : .alwaysOriginal)
        configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(pointSize: 18, weight: .medium)
        configuration.imagePadding = AppTheme.Spacing.small
        configuration.background.cornerRadius = AppTheme.Radius.control
        configuration.cornerStyle = .fixed
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFontMetrics(forTextStyle: .body)
                .scaledFont(for: .systemFont(ofSize: 17, weight: .semibold))
            return attributes
        }
        let button = UIButton(configuration: configuration)
        button.translatesAutoresizingMaskIntoConstraints = false
        return button
    }

    @objc private func requestAppleSignIn() {
        guard viewModel.requestSignIn() else { return }
        onAppleSignIn()
    }

    @objc private func requestGoogleSignIn() {
        guard viewModel.requestSignIn() else { return }
        onGoogleSignIn(self)
    }

    @objc private func requestCancellation() {
        guard viewModel.requestCancellation() else { return }
        onCancelSignIn()
    }

    @objc private func requestCleanupRetry() {
        onRetryCleanup()
    }

    @objc private func requestClose() {
        onClose()
    }
}

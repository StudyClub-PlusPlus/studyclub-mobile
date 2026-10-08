import Combine
import GoogleSignIn
import UIKit

@MainActor
final class LoginViewController: UIViewController {
    private let viewModel: LoginViewModel
    private let onGoogleSignIn: (LoginViewController) -> Void
    private let onCancelSignIn: () -> Void
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
    private let googleContainer: UIView = {
        let view = UIView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let statusRow: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alignment = .center
        view.spacing = AppTheme.Spacing.medium
        return view
    }()
    private let googleButton: GIDSignInButton = {
        let view = GIDSignInButton()
        view.style = .wide
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
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

    convenience init(
        onGoogleSignIn: @escaping (LoginViewController) -> Void,
        onCancelSignIn: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.init(
            viewModel: LoginViewModel(),
            onGoogleSignIn: onGoogleSignIn,
            onCancelSignIn: onCancelSignIn,
            onClose: onClose
        )
    }

    init(
        viewModel: LoginViewModel,
        onGoogleSignIn: @escaping (LoginViewController) -> Void,
        onCancelSignIn: @escaping () -> Void,
        onClose: @escaping () -> Void
    ) {
        self.viewModel = viewModel
        self.onGoogleSignIn = onGoogleSignIn
        self.onCancelSignIn = onCancelSignIn
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
            self.updateGoogleStyle()
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        providerGroup.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
        providerGroup.layer.borderColor = AppTheme.Palette.border.resolvedColor(with: traitCollection).cgColor
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

        content.addArrangedSubview(providerGroup)
        providerGroup.addArrangedSubview(googleContainer)
        googleContainer.addSubview(googleButton)
        // Wide style can fill the available width while the SDK owns its height.
        NSLayoutConstraint.activate([
            googleContainer.heightAnchor.constraint(equalTo: googleButton.heightAnchor, constant: 2),
            googleButton.centerYAnchor.constraint(equalTo: googleContainer.centerYAnchor),
            googleButton.leadingAnchor.constraint(equalTo: googleContainer.leadingAnchor),
            googleButton.trailingAnchor.constraint(equalTo: googleContainer.trailingAnchor)
        ])
        googleButton.addTarget(self, action: #selector(requestGoogleSignIn), for: .touchUpInside)
        updateGoogleStyle()

        providerGroup.addArrangedSubview(statusRow)
        statusRow.addArrangedSubview(spinner)
        spinner.setContentHuggingPriority(.required, for: .horizontal)
        spinner.setContentCompressionResistancePriority(.required, for: .horizontal)
        statusRow.addArrangedSubview(statusLabel)
        providerGroup.addArrangedSubview(cancelButton)
        cancelButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        cancelButton.addTarget(self, action: #selector(requestCancellation), for: .touchUpInside)
    }

    private func updateViews() {
        let busy = viewModel.state == .signingIn
        googleButton.isEnabled = viewModel.canSignIn
        statusLabel.text = viewModel.statusMessage
        statusRow.isHidden = viewModel.statusMessage == nil
        statusLabel.textColor = viewModel.state == .failure ? AppTheme.Palette.error : AppTheme.Palette.secondaryText
        spinner.isHidden = !busy
        if busy { spinner.startAnimating() } else { spinner.stopAnimating() }
        cancelButton.isHidden = !busy
    }

    private func updateGoogleStyle() {
        googleButton.colorScheme = traitCollection.userInterfaceStyle == .dark ? .dark : .light
    }

    @objc private func requestGoogleSignIn() {
        guard viewModel.requestSignIn() else { return }
        onGoogleSignIn(self)
    }

    @objc private func requestCancellation() {
        guard viewModel.requestCancellation() else { return }
        onCancelSignIn()
    }

    @objc private func requestClose() {
        onClose()
    }
}

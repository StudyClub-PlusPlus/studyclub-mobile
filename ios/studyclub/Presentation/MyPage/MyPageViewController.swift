import Combine
import UIKit

@MainActor
final class MyPageViewController: UIViewController {
    private let viewModel: MyPageViewModel
    private var cancellables = Set<AnyCancellable>()
    var onLogout: (() -> Void)?
    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.xLarge
        view.isLayoutMarginsRelativeArrangement = true
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(top: AppTheme.Spacing.xLarge, leading: AppTheme.Spacing.xLarge, bottom: AppTheme.Spacing.xLarge, trailing: AppTheme.Spacing.xLarge)
        view.backgroundColor = AppTheme.Palette.surface
        view.layer.cornerRadius = AppTheme.Radius.card
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let avatarView: UIImageView = {
        let view = UIImageView(image: UIImage(systemName: "person.crop.circle.fill"))
        view.contentMode = .scaleAspectFit
        view.tintColor = AppTheme.Palette.accent
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let headingLabel: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .title2)
        view.textColor = AppTheme.Palette.primaryText
        view.numberOfLines = 0
        return view
    }()
    private let bodyLabel: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        return view
    }()
    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()
    private let actionButton: UIButton = {
        let view = UIButton(type: .system)
        view.configuration = .filled()
        view.tintColor = AppTheme.Palette.accent
        return view
    }()
    private let demoButton: UIButton = {
        let view = UIButton(type: .system)
        view.configuration = .plain()
        view.setTitle("데모 계정으로 둘러보기", for: .normal)
        return view
    }()
    private let demoLabel: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .caption1)
        view.textColor = AppTheme.Palette.secondaryText
        view.text = "데모 계정 · 실제 회원 정보가 아닙니다"
        view.numberOfLines = 0
        return view
    }()

    init(viewModel: MyPageViewModel) {
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
        viewModel.statePublisher
            .sink { [weak self] _ in
                self?.updateViews()
            }
            .store(in: &cancellables)
    }

    private func configureView() {
        title = "마이페이지"
        navigationItem.largeTitleDisplayMode = .never
        view.backgroundColor = AppTheme.Palette.canvas
        view.tintColor = AppTheme.Palette.accent
        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor)
        ])
        scrollView.addSubview(stackView)
        let preferredWidth = stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * AppTheme.Spacing.large)
        preferredWidth.priority = UILayoutPriority(999)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.xxLarge),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xxLarge),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 560),
            preferredWidth
        ])
        stackView.addArrangedSubview(avatarView)
        avatarView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        stackView.addArrangedSubview(headingLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(activityIndicator)
        stackView.addArrangedSubview(demoLabel)
        stackView.addArrangedSubview(actionButton)
        let actionButtonHeight = actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50)
        actionButtonHeight.priority = UILayoutPriority(999)
        actionButtonHeight.isActive = true
        actionButton.addTarget(self, action: #selector(didTapAction), for: .touchUpInside)
        stackView.addArrangedSubview(demoButton)
        let demoButtonHeight = demoButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 44)
        demoButtonHeight.priority = UILayoutPriority(999)
        demoButtonHeight.isActive = true
        demoButton.addTarget(self, action: #selector(didTapDemo), for: .touchUpInside)
    }

    private func updateViews() {
        activityIndicator.stopAnimating()
        activityIndicator.isHidden = true
        demoButton.isHidden = true
        demoLabel.isHidden = true
        actionButton.isHidden = false
        actionButton.setTitle("로그인", for: .normal)
        switch viewModel.currentState {
        case .guest, .expired:
            headingLabel.text = viewModel.currentState == .expired ? "다시 로그인해 주세요" : "로그인이 필요해요"
            bodyLabel.text = viewModel.currentState == .expired
                ? "세션이 만료되었어요. 로그인하면 내 정보를 다시 확인할 수 있어요."
                : "로그인하고 내 계정 정보를 확인하세요."
            demoButton.isHidden = !viewModel.supportsDemo
        case .loading:
            headingLabel.text = "내 정보를 불러오는 중이에요"
            bodyLabel.text = "잠시만 기다려 주세요."
            activityIndicator.isHidden = false
            activityIndicator.startAnimating()
            actionButton.isHidden = true
        case .content:
            headingLabel.text = viewModel.nickname
            bodyLabel.text = "이메일\n" + viewModel.email
            actionButton.setTitle("로그아웃", for: .normal)
            demoLabel.isHidden = !viewModel.supportsDemo
        case .failure:
            headingLabel.text = "내 정보를 불러오지 못했어요"
            bodyLabel.text = "지금은 내 정보를 확인할 수 없어요. 이전 화면에서 스터디 탐색을 계속할 수 있어요."
            actionButton.setTitle("로그아웃", for: .normal)
        }
    }

    @objc private func didTapDemo() {
        viewModel.startDemoSession()
    }

    @objc private func didTapAction() {
        if viewModel.currentState == .content || viewModel.currentState == .failure {
            viewModel.logout()
            onLogout?()
        } else {
            guard presentedViewController == nil else {
                return
            }
            let login = LoginViewController(
                viewModel: LoginViewModel(state: .unavailable),
                onGoogleSignIn: { _ in },
                onCancelSignIn: {},
                onClose: { [weak self] in
                    self?.dismiss(animated: true)
                }
            )
            present(UINavigationController(rootViewController: login), animated: true)
        }
    }
}

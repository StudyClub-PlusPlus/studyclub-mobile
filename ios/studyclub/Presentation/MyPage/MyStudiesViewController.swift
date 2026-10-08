import Combine
import UIKit

@MainActor
final class MyStudiesViewController: UIViewController {
    private let viewModel: MyPageViewModel
    private var cancellables = Set<AnyCancellable>()
    var onProfile: (() -> Void)?
    private let messageLabel: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .body)
        view.textColor = AppTheme.Palette.secondaryText
        view.numberOfLines = 0
        view.textAlignment = .center
        return view
    }()
    private let loginButton: UIButton = {
        let view = UIButton(type: .system)
        view.configuration = .filled()
        view.setTitle("로그인", for: .normal)
        return view
    }()
    private let stackView: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.xLarge
        view.translatesAutoresizingMaskIntoConstraints = false
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
        title = "내 스터디"
        navigationController?.navigationBar.prefersLargeTitles = true
        view.backgroundColor = AppTheme.Palette.canvas
        view.tintColor = AppTheme.Palette.accent
        view.addSubview(stackView)
        stackView.addArrangedSubview(messageLabel)
        stackView.addArrangedSubview(loginButton)
        loginButton.addTarget(self, action: #selector(didTapLogin), for: .touchUpInside)
        NSLayoutConstraint.activate([
            stackView.centerYAnchor.constraint(equalTo: view.safeAreaLayoutGuide.centerYAnchor),
            stackView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.xLarge),
            stackView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.xLarge)
        ])
    }
    private func updateViews() {
        let isGuest = viewModel.currentState == .guest || viewModel.currentState == .expired
        messageLabel.text = isGuest ? "참여한 스터디와 일정을 한곳에서 확인하세요.\n로그인 후 이용할 수 있어요." : "참여 스터디와 일정 화면을 준비하고 있어요."
        loginButton.isHidden = !isGuest
    }
    @objc private func didTapLogin() {
        onProfile?()
    }
}

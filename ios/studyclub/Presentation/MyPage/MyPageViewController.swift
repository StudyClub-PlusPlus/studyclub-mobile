import UIKit

/// Keeps the profile card and shares SC52's account presentation and cleanup implementation.
@MainActor
final class MyPageViewController: SettingViewController {
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
        view.directionalLayoutMargins = .init(top: 24, leading: 24, bottom: 24, trailing: 24)
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
    private let activity: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        view.color = AppTheme.Palette.accent
        return view
    }()
    private let actionButton: UIButton = {
        let view = UIButton(type: .system)
        view.configuration = .filled()
        view.tintColor = AppTheme.Palette.accent
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override func configureView() {
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
        let preferredWidth = stackView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -32)
        preferredWidth.priority = .init(999)
        NSLayoutConstraint.activate([
            stackView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 32),
            stackView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -32),
            scrollView.contentLayoutGuide.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            stackView.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            stackView.widthAnchor.constraint(lessThanOrEqualToConstant: 560), preferredWidth
        ])
        stackView.addArrangedSubview(avatarView)
        avatarView.heightAnchor.constraint(equalToConstant: 72).isActive = true
        stackView.addArrangedSubview(headingLabel)
        stackView.addArrangedSubview(bodyLabel)
        stackView.addArrangedSubview(activity)
        stackView.addArrangedSubview(actionButton)
        actionButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        actionButton.addTarget(self, action: #selector(performAction), for: .touchUpInside)
    }

    override func updateViews() {
        activity.stopAnimating()
        actionButton.isHidden = false
        actionButton.tintColor = AppTheme.Palette.accent
        switch viewModel.state {
        case .hidden:
            headingLabel.text = "계정 기능을 준비하고 있어요"
            bodyLabel.text = "아직 로그인 기능이 제공되지 않아요."
            actionButton.isHidden = true
        case .guest:
            headingLabel.text = "로그인이 필요해요"
            bodyLabel.text = "로그인하고 내 계정 정보를 확인하세요."
            actionButton.setTitle("로그인", for: .normal)
        case .checking:
            headingLabel.text = "로그인 상태를 확인하고 있어요…"
            bodyLabel.text = "잠시만 기다려 주세요."
            activity.startAnimating()
            actionButton.isHidden = true
        case .connectionFailure:
            headingLabel.text = "로그인 상태를 확인하지 못했어요."
            bodyLabel.text = "연결을 확인하고 다시 시도해 주세요."
            actionButton.setTitle("다시 확인", for: .normal)
        case let .member(nickname):
            headingLabel.text = nickname
            bodyLabel.text = "로그인됨"
            actionButton.setTitle("로그아웃", for: .normal)
            actionButton.tintColor = AppTheme.Palette.error
        case let .logoutFailure(nickname):
            headingLabel.text = nickname
            bodyLabel.text = "로그아웃하지 못했어요. 다시 시도해 주세요."
            actionButton.setTitle("로그아웃 다시 시도", for: .normal)
            actionButton.tintColor = AppTheme.Palette.error
        }
    }

    @objc private func performAction() {
        switch viewModel.state {
        case .guest: requestAccountAction(.login)
        case .connectionFailure: requestAccountAction(.recheck)
        case .member, .logoutFailure: confirmLogout()
        case .hidden, .checking: break
        }
    }
}

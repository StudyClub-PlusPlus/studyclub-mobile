import UIKit

final class StudyListFooterView: UICollectionReusableView {
    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = true
        return view
    }()
    private let messageLabel: UILabel = {
        let view = UILabel()
        view.font = .preferredFont(forTextStyle: .footnote)
        view.textColor = AppTheme.Palette.secondaryText
        view.textAlignment = .center
        view.numberOfLines = 0
        return view
    }()
    let retryButton: UIButton = {
        let view = UIButton(type: .system)
        view.setTitle("다시 시도", for: .normal)
        return view
    }()
    private let stack: UIStackView = {
        let view = UIStackView()
        view.axis = .vertical
        view.alignment = .center
        view.spacing = AppTheme.Spacing.xSmall
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()

    override init(frame: CGRect) {
        super.init(frame: frame)
        addSubview(stack)
        stack.addArrangedSubview(spinner)
        stack.addArrangedSubview(messageLabel)
        stack.addArrangedSubview(retryButton)
        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
            stack.topAnchor.constraint(greaterThanOrEqualTo: topAnchor, constant: AppTheme.Spacing.small),
            stack.bottomAnchor.constraint(lessThanOrEqualTo: bottomAnchor, constant: -AppTheme.Spacing.small),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: AppTheme.Spacing.regular),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -AppTheme.Spacing.regular)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func updateViews(_ state: MainViewModel.PageState) {
        spinner.stopAnimating()
        messageLabel.isHidden = true
        retryButton.isHidden = true
        switch state {
        case .idle: break
        case .loading:
            spinner.startAnimating()
        case .failure:
            messageLabel.text = "다음 스터디를 불러오지 못했어요."
            messageLabel.isHidden = false
            retryButton.isHidden = false
        case .stalled:
            messageLabel.text = "목록이 변경됐어요. 당겨서 새로고침해 주세요."
            messageLabel.isHidden = false
        }
    }
}

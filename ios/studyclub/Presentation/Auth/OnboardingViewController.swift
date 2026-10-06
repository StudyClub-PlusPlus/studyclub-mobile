import Combine
import UIKit

@MainActor
final class OnboardingViewController: UIViewController, UITextFieldDelegate {
    private let viewModel: OnboardingViewModel
    private let onSubmit: ((OnboardingViewModel.Input) -> Void)?
    private let onRecheck: (() -> Void)?
    private let onClose: (() -> Void)?
    private var subscriptions = Set<AnyCancellable>()

    private let scrollView: UIScrollView = {
        let view = UIScrollView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.keyboardDismissMode = .interactive
        return view
    }()
    private let content: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.xLarge
        return view
    }()
    private let heading = OnboardingViewController.label("스터디클럽에서 사용할 정보를 알려주세요", style: .title2)
    private let introduction = OnboardingViewController.label("닉네임과 시간대를 확인하고 필요한 항목에 동의해 주세요.", style: .body, secondary: true)
    private let informationGroup = OnboardingViewController.group()
    private let requiredGroup = OnboardingViewController.group()
    private let optionalGroup = OnboardingViewController.group()
    private let nicknameRow = OnboardingViewController.paddedRow()
    private let timeZoneRow = OnboardingViewController.paddedRow()
    private let nicknameTitle = OnboardingViewController.label("닉네임", style: .headline)
    private let nicknameHelp = OnboardingViewController.label("스터디클럽에서 사용할 이름이에요.", style: .subheadline, secondary: true)
    private let timeZoneTitle = OnboardingViewController.label("시간대", style: .headline)
    private let timeZoneHelp = OnboardingViewController.label("스터디 일정은 이 시간대를 기준으로 표시돼요.", style: .subheadline, secondary: true)
    private let requiredTitle = OnboardingViewController.label("필수 동의", style: .subheadline, secondary: true)
    private let optionalTitle = OnboardingViewController.label("선택 동의", style: .subheadline, secondary: true)
    private let stateArea: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.medium
        return view
    }()
    private let progressRow: UIStackView = {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.alignment = .center
        view.spacing = AppTheme.Spacing.medium
        return view
    }()
    private let nickname: UITextField = {
        let view = UITextField()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.borderStyle = .roundedRect
        view.backgroundColor = AppTheme.Palette.surface
        view.textColor = AppTheme.Palette.primaryText
        view.tintColor = AppTheme.Palette.accent
        view.placeholder = "닉네임을 입력하세요"
        view.font = .preferredFont(forTextStyle: .body)
        view.adjustsFontForContentSizeCategory = true
        view.autocorrectionType = .no
        view.autocapitalizationType = .none
        view.returnKeyType = .done
        return view
    }()
    private let timeZone: UIButton = {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: "chevron.right")
        configuration.imagePlacement = .trailing
        configuration.imagePadding = AppTheme.Spacing.small
        configuration.contentInsets = .zero
        configuration.titleAlignment = .leading
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .body)
            attributes.foregroundColor = AppTheme.Palette.primaryText
            return attributes
        }
        configuration.subtitleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .subheadline)
            attributes.foregroundColor = AppTheme.Palette.secondaryText
            return attributes
        }
        view.configuration = configuration
        view.contentHorizontalAlignment = .leading
        view.titleLabel?.numberOfLines = 0
        view.titleLabel?.font = .preferredFont(forTextStyle: .body)
        view.tintColor = AppTheme.Palette.accent
        return view
    }()
    private let nicknameError = OnboardingViewController.errorLabel()
    private let consentError = OnboardingViewController.errorLabel()
    private let ageSwitch = OnboardingViewController.consentSwitch()
    private let termsSwitch = OnboardingViewController.consentSwitch()
    private let privacySwitch = OnboardingViewController.consentSwitch()
    private let marketingSwitch = OnboardingViewController.consentSwitch()
    private let spinner: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.translatesAutoresizingMaskIntoConstraints = false
        return view
    }()
    private let statusLabel = OnboardingViewController.label("", style: .subheadline, secondary: true)
    private let failureLabel = OnboardingViewController.errorLabel()
    private let submitButton: UIButton = {
        let view = UIButton(type: .system)
        view.translatesAutoresizingMaskIntoConstraints = false
        var configuration = UIButton.Configuration.filled()
        configuration.title = "가입 완료"
        configuration.baseBackgroundColor = AppTheme.Palette.accent
        configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { attributes in
            var attributes = attributes
            attributes.font = UIFont.preferredFont(forTextStyle: .headline)
            return attributes
        }
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)
        view.configuration = configuration
        return view
    }()

    convenience init() {
        self.init(viewModel: OnboardingViewModel())
    }

    init(viewModel: OnboardingViewModel,
         onSubmit: ((OnboardingViewModel.Input) -> Void)? = nil,
         onRecheck: (() -> Void)? = nil,
         onClose: (() -> Void)? = nil) {
        self.viewModel = viewModel
        self.onSubmit = onSubmit
        self.onRecheck = onRecheck
        self.onClose = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
        viewModel.statePublisher.sink { [weak self] _ in self?.updateViews() }.store(in: &subscriptions)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        for group in [informationGroup, requiredGroup, optionalGroup] {
            group.layer.borderWidth = 1 / max(traitCollection.displayScale, 1)
            group.layer.borderColor = AppTheme.Palette.border.resolvedColor(with: traitCollection).cgColor
        }
    }

    private func configureView() {
        title = "가입 정보 입력"
        view.backgroundColor = AppTheme.Palette.canvas
        view.tintColor = AppTheme.Palette.accent
        navigationController?.navigationBar.tintColor = AppTheme.Palette.accent
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.hidesBackButton = true
        isModalInPresentation = true
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "닫기", style: .plain, target: self, action: #selector(requestClose))

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.keyboardLayoutGuide.topAnchor)
        ])

        scrollView.addSubview(content)
        let equalWidth = content.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -2 * AppTheme.Spacing.large)
        equalWidth.priority = .defaultHigh
        NSLayoutConstraint.activate([
            content.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.xLarge),
            content.centerXAnchor.constraint(equalTo: scrollView.frameLayoutGuide.centerXAnchor),
            content.leadingAnchor.constraint(greaterThanOrEqualTo: scrollView.contentLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.large),
            content.trailingAnchor.constraint(lessThanOrEqualTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.large),
            content.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xLarge),
            content.widthAnchor.constraint(lessThanOrEqualToConstant: 560), equalWidth
        ])
        content.addArrangedSubview(heading)
        content.setCustomSpacing(AppTheme.Spacing.medium, after: heading)
        content.addArrangedSubview(introduction)

        content.addArrangedSubview(informationGroup)
        informationGroup.addArrangedSubview(nicknameRow)
        nicknameRow.addArrangedSubview(nicknameTitle)
        nicknameRow.addArrangedSubview(nickname)
        nickname.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        nickname.text = viewModel.input.nickname
        nickname.delegate = self
        nickname.addTarget(self, action: #selector(nicknameChanged), for: .editingChanged)
        nicknameRow.addArrangedSubview(nicknameHelp)
        nicknameRow.addArrangedSubview(nicknameError)

        addSeparator(to: informationGroup)
        informationGroup.addArrangedSubview(timeZoneRow)
        timeZoneRow.addArrangedSubview(timeZoneTitle)
        timeZoneRow.addArrangedSubview(timeZone)
        timeZone.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        timeZone.addAction(UIAction { [weak self] _ in self?.chooseTimeZone() }, for: .touchUpInside)
        timeZoneRow.addArrangedSubview(timeZoneHelp)

        content.addArrangedSubview(requiredTitle)
        content.setCustomSpacing(AppTheme.Spacing.small, after: requiredTitle)
        content.addArrangedSubview(requiredGroup)
        requiredGroup.addArrangedSubview(consent("만 14세 이상입니다", control: ageSwitch))
        addSeparator(to: requiredGroup)
        requiredGroup.addArrangedSubview(consent("이용약관에 동의합니다", control: termsSwitch, document: .terms))
        addSeparator(to: requiredGroup)
        requiredGroup.addArrangedSubview(consent("개인정보 처리방침에 동의합니다", control: privacySwitch, document: .privacy))
        content.addArrangedSubview(consentError)

        content.addArrangedSubview(optionalTitle)
        content.setCustomSpacing(AppTheme.Spacing.small, after: optionalTitle)
        content.addArrangedSubview(optionalGroup)
        optionalGroup.addArrangedSubview(consent("마케팅 정보 수신에 동의합니다", control: marketingSwitch, document: .marketing))

        content.addArrangedSubview(stateArea)
        stateArea.addArrangedSubview(progressRow)
        progressRow.addArrangedSubview(spinner)
        progressRow.addArrangedSubview(statusLabel)
        stateArea.addArrangedSubview(failureLabel)
        content.addArrangedSubview(submitButton)
        submitButton.heightAnchor.constraint(greaterThanOrEqualToConstant: 50).isActive = true
        submitButton.addAction(UIAction { [weak self] _ in self?.submit() }, for: .touchUpInside)
    }

    private func updateViews() {
        let input = viewModel.input
        // Never replace text while the user is composing Korean with the keyboard.
        if !nickname.isFirstResponder && nickname.markedTextRange == nil { nickname.text = input.nickname }
        nickname.isEnabled = viewModel.isEditing
        timeZone.isEnabled = viewModel.isEditing
        let localized = TimeZone(identifier: input.timeZone)?.localizedName(for: .standard, locale: .current) ?? ""
        timeZone.configuration?.title = input.timeZone
        timeZone.configuration?.subtitle = localized
        ageSwitch.isOn = input.age14Confirmed
        termsSwitch.isOn = input.termsOfServiceAgreed
        privacySwitch.isOn = input.privacyPolicyAgreed
        marketingSwitch.isOn = input.marketingAgreed
        for control in [ageSwitch, termsSwitch, privacySwitch, marketingSwitch] { control.isEnabled = viewModel.isEditing }
        nicknameError.text = viewModel.nicknameError.map { "ⓘ \($0)" }
        nicknameError.isHidden = viewModel.nicknameError == nil
        consentError.text = viewModel.consentError.map { "ⓘ \($0)" }
        consentError.isHidden = viewModel.consentError == nil
        failureLabel.text = viewModel.errorMessage
        failureLabel.isHidden = viewModel.errorMessage == nil
        switch viewModel.state {
        case .editing, .closed:
            statusLabel.text = nil
        case .submitting:
            statusLabel.text = "가입을 완료하고 있어요…"
        case .unknownStatus:
            statusLabel.text = "가입 완료 여부를 확인하지 못했어요. 다시 제출하지 말고 완료 여부를 확인해 주세요."
        case .checkingStatus:
            statusLabel.text = "가입 완료 여부를 확인하고 있어요…"
        }
        statusLabel.isHidden = statusLabel.text == nil
        stateArea.isHidden = statusLabel.text == nil && viewModel.errorMessage == nil
        spinner.isHidden = !viewModel.isBusy
        if viewModel.isBusy { spinner.startAnimating() } else { spinner.stopAnimating() }
        submitButton.setTitle(viewModel.requiresStatusCheck ? "다시 확인" : "가입 완료", for: .normal)
        submitButton.isEnabled = viewModel.canSubmit || viewModel.state == .unknownStatus
    }

    @objc private func nicknameChanged() { viewModel.updateNickname(nickname.text ?? "") }

    @objc private func consentsChanged() {
        viewModel.updateConsents(age: ageSwitch.isOn, terms: termsSwitch.isOn,
                                 privacy: privacySwitch.isOn, marketing: marketingSwitch.isOn)
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        viewModel.updateNickname(textField.text ?? "")
        viewModel.validateNickname()
    }

    private func submit() {
        view.endEditing(true)
        if viewModel.requiresStatusCheck {
            if viewModel.beginStatusCheck() { onRecheck?() }
        } else if let input = viewModel.submit() {
            onSubmit?(input)
        }
    }

    private func chooseTimeZone() {
        view.endEditing(true)
        navigationController?.pushViewController(TimeZoneViewController(selected: viewModel.input.timeZone) { [weak self] zone in
            self?.viewModel.selectTimeZone(zone)
        }, animated: true)
    }

    @objc private func requestClose() {
        view.endEditing(true)
        let uncertain = viewModel.state == .submitting || viewModel.requiresStatusCheck
        guard uncertain || viewModel.hasChanges else { close(); return }
        let alert = UIAlertController(
            title: uncertain ? "가입 화면을 닫을까요?" : "가입을 그만둘까요?",
            message: uncertain ? "서버에서 가입이 완료됐을 수 있어요. 다음 로그인에서 완료 여부를 확인해요." : "입력한 내용은 저장되지 않아요. 다음에는 Google 로그인부터 다시 시작해요.",
            preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: uncertain ? "계속 확인" : "계속 입력", style: .cancel))
        alert.addAction(UIAlertAction(title: uncertain ? "닫기" : "그만두기", style: .destructive) { [weak self] _ in self?.close() })
        present(alert, animated: true)
    }

    private func close() {
        guard viewModel.state != .closed else { return }
        viewModel.close()
        if let onClose { onClose() }
        else { (navigationController?.presentingViewController ?? presentingViewController)?.dismiss(animated: true) }
    }

    private func openDocument(_ kind: AuthDocuments.Kind) {
        let controller = UIViewController()
        controller.title = kind.rawValue
        controller.view.backgroundColor = AppTheme.Palette.canvas
        let text = Self.label(AuthDocuments().content(for: kind), style: .body)
        let scroll = UIScrollView()
        scroll.translatesAutoresizingMaskIntoConstraints = false
        controller.view.addSubview(scroll)
        NSLayoutConstraint.activate([
            scroll.topAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.topAnchor),
            scroll.leadingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.trailingAnchor),
            scroll.bottomAnchor.constraint(equalTo: controller.view.safeAreaLayoutGuide.bottomAnchor)
        ])
        scroll.addSubview(text)
        NSLayoutConstraint.activate([
            text.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: AppTheme.Spacing.xLarge),
            text.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor, constant: AppTheme.Spacing.large),
            text.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor, constant: -AppTheme.Spacing.large),
            text.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -AppTheme.Spacing.xLarge),
            text.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -2 * AppTheme.Spacing.large)
        ])
        navigationController?.pushViewController(controller, animated: true)
    }

    private static func label(_ text: String, style: UIFont.TextStyle, secondary: Bool = false) -> UILabel {
        let view = UILabel()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.text = text
        view.font = .preferredFont(forTextStyle: style)
        view.textColor = secondary ? AppTheme.Palette.secondaryText : AppTheme.Palette.primaryText
        view.numberOfLines = 0
        view.adjustsFontForContentSizeCategory = true
        return view
    }

    private static func errorLabel() -> UILabel {
        let view = label("", style: .subheadline)
        view.textColor = AppTheme.Palette.error
        view.isHidden = true
        return view
    }

    private static func group() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.backgroundColor = AppTheme.Palette.surface
        view.layer.cornerRadius = AppTheme.Radius.card
        view.clipsToBounds = true
        return view
    }

    private static func consentSwitch() -> UISwitch {
        let view = UISwitch()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.onTintColor = AppTheme.Palette.accent
        return view
    }

    private static func paddedRow() -> UIStackView {
        let view = UIStackView()
        view.translatesAutoresizingMaskIntoConstraints = false
        view.axis = .vertical
        view.spacing = AppTheme.Spacing.small
        view.isLayoutMarginsRelativeArrangement = true
        view.directionalLayoutMargins = NSDirectionalEdgeInsets(
            top: AppTheme.Spacing.medium, leading: AppTheme.Spacing.regular,
            bottom: AppTheme.Spacing.medium, trailing: AppTheme.Spacing.regular)
        return view
    }

    private func addSeparator(to group: UIStackView) {
        let separator = UIView()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.backgroundColor = AppTheme.Palette.border
        group.addArrangedSubview(separator)
        separator.heightAnchor.constraint(equalToConstant: 1 / max(traitCollection.displayScale, 1)).isActive = true
    }

    private func consent(_ text: String, control: UISwitch, document: AuthDocuments.Kind? = nil) -> UIView {
        let container = Self.paddedRow()
        let row = UIStackView()
        row.translatesAutoresizingMaskIntoConstraints = false
        row.spacing = AppTheme.Spacing.regular
        row.alignment = .center
        container.addArrangedSubview(row)
        row.addArrangedSubview(Self.label(text, style: .body))
        control.translatesAutoresizingMaskIntoConstraints = false
        row.addArrangedSubview(control)
        control.setContentHuggingPriority(.required, for: .horizontal)
        control.setContentCompressionResistancePriority(.required, for: .horizontal)
        control.addTarget(self, action: #selector(consentsChanged), for: .valueChanged)
        row.heightAnchor.constraint(greaterThanOrEqualToConstant: 32).isActive = true
        if let document { container.addArrangedSubview(documentButton(document)) }
        return container
    }

    private func documentButton(_ kind: AuthDocuments.Kind) -> UIButton {
        let button = UIButton(type: .system)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.setTitle("\(kind.rawValue) 보기", for: .normal)
        button.tintColor = AppTheme.Palette.accent
        button.contentHorizontalAlignment = .leading
        button.titleLabel?.font = .preferredFont(forTextStyle: .subheadline)
        button.titleLabel?.numberOfLines = 0
        button.heightAnchor.constraint(greaterThanOrEqualToConstant: 44).isActive = true
        button.addAction(UIAction { [weak self] _ in self?.openDocument(kind) }, for: .touchUpInside)
        return button
    }
}

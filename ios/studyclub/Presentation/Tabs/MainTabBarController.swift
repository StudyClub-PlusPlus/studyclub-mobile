import Combine
import UIKit
#if DEBUG
import SwiftUI
#endif

@MainActor
final class MainTabBarController: UITabBarController {
    private var accountViewModel: SettingAccountViewModel?
    private var accountController: SettingViewController?
    private var accountSubscription: AnyCancellable?
    private var profileNavigation: UINavigationController?
    private var isMyPageEnabled = false
    private var closingProfile = false

    @objc private func openMyPage() {
        presentProfile(startLogin: false)
    }

    private func presentProfile(startLogin: Bool) {
        guard isMyPageEnabled, let accountViewModel, presentedViewController == nil else { return }
        let controller = MyPageViewController(viewModel: accountViewModel)
        controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close, target: self, action: #selector(closeProfile)
        )
        if startLogin {
            controller.onAccountFlowDismissed = { [weak self] in self?.dismissProfile() }
        }
        accountController = controller
        let navigation = UINavigationController(rootViewController: controller)
        navigation.modalPresentationStyle = .fullScreen
        navigation.isModalInPresentation = true
        profileNavigation = navigation
        present(navigation, animated: true) {
            if startLogin { accountViewModel.startLogin() }
        }
    }

    @objc private func closeProfile() {
        guard let accountViewModel, !closingProfile else { return }
        guard accountViewModel.cleanupBlocked || accountViewModel.presentation != .none else {
            dismissProfile()
            return
        }
        closingProfile = true
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.closingProfile = false }
            do {
                try await self.accountController?.invalidateAccountWorkflow()
                self.dismissProfile()
            } catch {
                let alert = UIAlertController(title: "계정 정리를 끝내지 못했어요.", message: "이 화면을 유지했어요. 다시 닫기를 눌러 시도해 주세요.", preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "확인", style: .default))
                self.profileNavigation?.present(alert, animated: true)
            }
        }
    }

    private func dismissProfile() {
        guard let profileNavigation, presentedViewController === profileNavigation else { return }
        dismiss(animated: true) { [weak self] in
            self?.profileNavigation = nil
            self?.accountController = nil
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        installTabs()

        #if DEBUG
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(openDevelopmentSettings))
        longPress.minimumPressDuration = 0.7
        longPress.delegate = self
        tabBar.addGestureRecognizer(longPress)
        #endif
    }

    private func settingViewController() -> SettingViewController? {
        accountController
    }

    #if DEBUG
    /// Saved repository mode still needs a new root after a failed invalidation.
    private var pendingRepositoryRoot = false
    private var installingRepositoryRoot = false
    private var rootInstallFailureAlert: UIAlertController?
    #endif

    private func installTabs() {
        let main = UINavigationController(
            rootViewController: MainViewController(viewModel: MainViewModel())
        )
        main.tabBarItem = UITabBarItem(
            title: "스터디", image: UIImage(systemName: "books.vertical"), tag: 0
        )

        let accountViewModel = SettingAccountViewModel()
        self.accountViewModel = accountViewModel
        let settingController = SettingViewController(viewModel: accountViewModel)
        let setting = UINavigationController(rootViewController: settingController)
        setting.tabBarItem = UITabBarItem(
            title: "설정", image: UIImage(systemName: "gearshape"), tag: 1
        )

        isMyPageEnabled = DevelopmentSettingsStore().isEnabled(FeatureFlag.myPage.definition)
        if isMyPageEnabled {
            let myStudies = MyStudiesViewController(viewModel: accountViewModel)
            myStudies.onProfile = { [weak self] in
                self?.presentProfile(startLogin: true)
            }
            let myNavigation = UINavigationController(rootViewController: myStudies)
            myNavigation.tabBarItem = UITabBarItem(title: "내 스터디", image: UIImage(systemName: "list.bullet"), tag: 1)
            for controller in [main.viewControllers[0], myStudies] {
                controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: "프로필", style: .plain, target: self, action: #selector(openMyPage)
                )
            }
            viewControllers = [main, myNavigation]
            accountController = nil
        } else {
            viewControllers = [main, setting]
            accountController = settingController
        }
        tabBar.tintColor = AppTheme.Palette.accent
        #if DEBUG
        accountSubscription = accountViewModel.statePublisher.sink { [weak self] state in
            guard let self, self.pendingRepositoryRoot else { return }
            switch state {
            case .guest, .member, .hidden: self.scheduleRepositoryRootInstall()
            default: break
            }
        }
        #endif
    }
}

#if DEBUG
extension MainTabBarController: UIGestureRecognizerDelegate {
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer
    ) -> Bool {
        true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        guard let title = viewControllers?.first?.tabBarItem.title else { return false }
        let point = touch.location(in: tabBar)

        // UITabBarItem has no public view/frame. Match the rendered UIControl by its
        // current title, without private class names, KVC, or screen-width estimates.
        // Resolve each touch again so rotation and native floating-tab layout are respected.
        func containsTitle(_ view: UIView) -> Bool {
            if let label = view as? UILabel, label.text == title { return true }
            return view.subviews.contains(where: containsTitle)
        }
        func containsMainControl(_ view: UIView) -> Bool {
            guard !view.isHidden, view.alpha > 0 else { return false }
            if view is UIControl, containsTitle(view),
               view.convert(view.bounds, to: tabBar).contains(point) { return true }
            return view.subviews.contains(where: containsMainControl)
        }
        return containsMainControl(tabBar)
    }

    @objc private func openDevelopmentSettings(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began, presentedViewController == nil else { return }
        let settings = DevelopmentSettingsView(
            onRepositoryChange: { [weak self] in
                self?.dismiss(animated: true) { [weak self] in
                    self?.scheduleRepositoryRootInstall()
                }
            },
            onAuthFlagChange: { [weak self] in
                self?.accountViewModel?.updateFeatureVisibility(
                    isEnabled: DevelopmentSettingsStore().isEnabled(FeatureFlag.googleLogin.definition)
                )
            }
        )
        present(UIHostingController(rootView: settings), animated: true)
    }

    private func scheduleRepositoryRootInstall() {
        pendingRepositoryRoot = true
        guard !installingRepositoryRoot else { return }
        installingRepositoryRoot = true
        Task { @MainActor in
            await self.installPendingRepositoryRoot()
            self.installingRepositoryRoot = false
        }
    }

    private func installPendingRepositoryRoot() async {
        guard pendingRepositoryRoot else { return }
        let previous = settingViewController()
        do {
            if let previous { try await previous.invalidateAccountWorkflow() }
            else { try await accountViewModel?.invalidate() }
            dismissRootInstallFailure()
            installTabs()
            selectedIndex = 0
            pendingRepositoryRoot = false
        } catch {
            previous?.onSessionSettled = { [weak self] state in
                guard let self, self.pendingRepositoryRoot else { return }
                switch state {
                case .guest, .member, .hidden:
                    self.scheduleRepositoryRootInstall()
                default:
                    break
                }
            }
            presentRootInstallFailure()
        }
    }

    /// The mode switch did not finish. Stay on the current root and ask Main to retry the same cleanup.
    private func presentRootInstallFailure() {
        guard pendingRepositoryRoot, rootInstallFailureAlert == nil, presentedViewController == nil else { return }
        let alert = UIAlertController(
            title: "화면을 바꾸지 못했어요.",
            message: "이전 화면을 유지했어요. 지금 다시 시도하거나, 설정에서 나중에 다시 확인할 수 있어요.",
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: "나중에", style: .cancel) { [weak self] _ in
            self?.rootInstallFailureAlert = nil
        })
        alert.addAction(UIAlertAction(title: "다시 시도", style: .default) { [weak self] _ in
            guard let self else { return }
            self.rootInstallFailureAlert = nil
            let retry: () -> Void = { [weak self] in
                self?.scheduleRepositoryRootInstall()
                return
            }
            if self.presentedViewController == nil {
                retry()
            } else {
                self.dismiss(animated: false, completion: retry)
            }
        })
        rootInstallFailureAlert = alert
        present(alert, animated: true)
    }

    private func dismissRootInstallFailure() {
        guard let alert = rootInstallFailureAlert else { return }
        rootInstallFailureAlert = nil
        alert.dismiss(animated: false)
    }
}
#endif

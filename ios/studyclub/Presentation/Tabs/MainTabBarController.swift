import UIKit
#if DEBUG
import SwiftUI
#endif

@MainActor
final class MainTabBarController: UITabBarController {
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
        viewControllers?
            .compactMap { $0 as? UINavigationController }
            .compactMap { $0.viewControllers.first as? SettingViewController }
            .first
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

        let setting = UINavigationController(rootViewController: SettingViewController())
        setting.tabBarItem = UITabBarItem(
            title: "설정", image: UIImage(systemName: "gearshape"), tag: 1
        )

        viewControllers = [main, setting]
        tabBar.tintColor = AppTheme.Palette.accent

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
                self?.settingViewController()?.refreshFeatureVisibility()
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
            try await previous?.invalidateAccountWorkflow()
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

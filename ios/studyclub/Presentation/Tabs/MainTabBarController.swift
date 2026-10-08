import UIKit
#if DEBUG
import SwiftUI
#endif

@MainActor
final class MainTabBarController: UITabBarController {
    private var myPageViewModel: MyPageViewModel?

    @objc private func openMyPage() {
        guard let myPageViewModel, myPageViewModel.isEnabled,
              let navigation = selectedViewController as? UINavigationController,
              !(navigation.topViewController is MyPageViewController) else {
            return
        }
        let controller = MyPageViewController(viewModel: myPageViewModel)
        controller.onLogout = { [weak self] in
            guard let self else {
                return
            }
            for case let navigation as UINavigationController in self.viewControllers ?? [] {
                navigation.popToRootViewController(animated: false)
            }
            self.selectedIndex = 0
        }
        navigation.pushViewController(controller, animated: true)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        configureTabs()

        #if DEBUG
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(openDevelopmentSettings))
        longPress.minimumPressDuration = 0.7
        longPress.delegate = self
        tabBar.addGestureRecognizer(longPress)
        #endif
    }

    private func configureTabs() {
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

        let accountViewModel = MyPageViewModel()
        myPageViewModel = accountViewModel
        if accountViewModel.isEnabled {
            let myStudies = MyStudiesViewController(viewModel: accountViewModel)
            myStudies.onProfile = { [weak self] in
                self?.openMyPage()
            }
            let myNavigation = UINavigationController(rootViewController: myStudies)
            myNavigation.tabBarItem = UITabBarItem(title: "내 스터디", image: UIImage(systemName: "calendar"), tag: 1)
            for controller in [main.viewControllers[0], myStudies] {
                controller.navigationItem.rightBarButtonItem = UIBarButtonItem(
                    title: "프로필", style: .plain, target: self, action: #selector(openMyPage)
                )
            }
            viewControllers = [main, myNavigation]
        } else {
            viewControllers = [main, setting]
        }
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
        let settings = DevelopmentSettingsView { [weak self] in
            self?.dismiss(animated: true) { [weak self] in
                self?.configureTabs()
                self?.selectedIndex = 0
            }
        }
        present(UIHostingController(rootView: settings), animated: true)
    }
}
#endif

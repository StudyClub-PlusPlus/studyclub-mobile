import UIKit

@MainActor
final class MainTabBarController: UITabBarController {
    override func viewDidLoad() {
        super.viewDidLoad()
        configureView()
    }

    private func configureView() {
        let main = UINavigationController(
            rootViewController: MainViewController(viewModel: MainViewModel())
        )
        main.tabBarItem = UITabBarItem(
            title: "스터디", image: UIImage(systemName: "books.vertical"), tag: 0
        )
        main.tabBarItem.accessibilityIdentifier = "tab.main"

        let setting = UINavigationController(rootViewController: SettingViewController())
        setting.tabBarItem = UITabBarItem(
            title: "설정", image: UIImage(systemName: "gearshape"), tag: 1
        )
        setting.tabBarItem.accessibilityIdentifier = "tab.setting"

        viewControllers = [main, setting]
        tabBar.tintColor = AppTheme.Palette.accent

        #if DEBUG
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(openDevelopmentSettings))
        longPress.minimumPressDuration = 0.7
        longPress.delegate = self
        tabBar.addGestureRecognizer(longPress)
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
        let settings = DevelopmentSettingsViewController()
        present(UINavigationController(rootViewController: settings), animated: true)
    }
}
#endif

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
    }
}

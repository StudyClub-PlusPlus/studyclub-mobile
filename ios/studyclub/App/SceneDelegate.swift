import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let window = UIWindow(windowScene: windowScene)
        self.window = window
        rebuildRoot()
        window.makeKeyAndVisible()
    }

    private func rebuildRoot() {
        let tabBarController = MainTabBarController()
        #if DEBUG
        tabBarController.onRepositoryChange = { [weak self] in
            self?.rebuildRoot()
        }
        #endif
        window?.rootViewController = tabBarController
    }
}

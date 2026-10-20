import GoogleSignIn
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
        window.overrideUserInterfaceStyle = AppTheme.isStudyDesignSystemEnabled ? .light : .unspecified
        self.window = window
        window.rootViewController = MainTabBarController()
        window.makeKeyAndVisible()
    }

    /// Delivers the Google OAuth redirect to the SDK. Other URLs are ignored.
    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        for context in URLContexts {
            _ = GIDSignIn.sharedInstance.handle(context.url)
        }
    }
}

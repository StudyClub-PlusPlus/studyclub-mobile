import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(
        _ scene: UIScene,
        willConnectTo session: UISceneSession,
        options connectionOptions: UIScene.ConnectionOptions
    ) {
        guard let windowScene = scene as? UIWindowScene else { return }

        let repository: RepositoryProtocol = RepositoryFactory.makeStudyRepository()
        let viewModel = MainViewModel(repository: repository)
        let mainViewController = MainViewController(viewModel: viewModel, repository: repository)
        let navigationController = UINavigationController(rootViewController: mainViewController)

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
    }
}

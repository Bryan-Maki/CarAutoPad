import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        if NSClassFromString("XCTestCase") != nil || ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil {
            let blankVC = UIViewController()
            blankVC.view.backgroundColor = .systemBackground
            window = UIWindow(windowScene: windowScene)
            window?.rootViewController = blankVC
            window?.makeKeyAndVisible()
            return
        }

        let rootViewController = MainViewController()

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        ConnectionManager.shared.disconnectForAppTermination()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        ConnectionManager.shared.handleWillEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        ConnectionManager.shared.handleDidEnterBackground()
    }
}

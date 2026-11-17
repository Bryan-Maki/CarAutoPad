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

        UserDefaults.standard.removeObject(forKey: "projection-app-language")
        let rootViewController = MainViewController()

        window = UIWindow(windowScene: windowScene)
        window?.rootViewController = rootViewController
        window?.makeKeyAndVisible()
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        guard NSClassFromString("XCTestCase") == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        ConnectionManager.shared.disconnectForAppTermination()
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        guard NSClassFromString("XCTestCase") == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        L10n.refreshSystemLanguageOnForeground()
    }

    func sceneWillResignActive(_ scene: UIScene) {
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        guard NSClassFromString("XCTestCase") == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        L10n.refreshSystemLanguageOnForeground()
        ConnectionManager.shared.handleWillEnterForeground()
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        guard NSClassFromString("XCTestCase") == nil && ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }
        ConnectionManager.shared.handleDidEnterBackground()
    }
}

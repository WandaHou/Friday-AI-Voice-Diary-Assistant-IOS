import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private let appVersion = "Friday 1.0"

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        let window = UIWindow(windowScene: windowScene)
        
        let storageManager = StorageManager()
        let viewModel = TranscriptListViewModelImpl(storageManager: storageManager)
        let transcriptListVC = TranscriptListViewController(viewModel: viewModel)
        transcriptListVC.title = "Recordings"
        
        let navigationController = UINavigationController(rootViewController: transcriptListVC)
        navigationController.navigationBar.prefersLargeTitles = true
        
        let versionLabel = UILabel()
        versionLabel.text = appVersion
        versionLabel.textColor = .gray
        versionLabel.textAlignment = .center
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        window.addSubview(versionLabel)
        
        NSLayoutConstraint.activate([
            versionLabel.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -20),
            versionLabel.centerXAnchor.constraint(equalTo: window.centerXAnchor),
            versionLabel.heightAnchor.constraint(equalToConstant: 20)
        ])
        
        window.rootViewController = navigationController
        window.makeKeyAndVisible()
        self.window = window
    }
} 

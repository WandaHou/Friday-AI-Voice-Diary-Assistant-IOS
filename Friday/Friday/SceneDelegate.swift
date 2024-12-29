import UIKit


class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var isAwake = false
    
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = (scene as? UIWindowScene) else { return }
        
        window = UIWindow(windowScene: windowScene)
        let viewController = UIViewController()
        viewController.view.backgroundColor = .white
        
        let versionLabel = UILabel()
        versionLabel.text = "Friday1.0"
        versionLabel.textAlignment = .center
        versionLabel.font = .systemFont(ofSize: 24, weight: .bold)
        versionLabel.textColor = .black
        versionLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let isLabel = UILabel()
        isLabel.text = "is"
        isLabel.textAlignment = .center
        isLabel.font = .systemFont(ofSize: 24)
        isLabel.textColor = .black
        isLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.setTitle(isAwake ? "Awake" : "Asleep", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleButtonTapped), for: .touchUpInside)
        
        viewController.view.addSubview(versionLabel)
        viewController.view.addSubview(isLabel)
        viewController.view.addSubview(button)
        
        NSLayoutConstraint.activate([
            versionLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            versionLabel.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor, constant: -50),
            
            isLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            isLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 15),
            
            button.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            button.topAnchor.constraint(equalTo: isLabel.bottomAnchor, constant: 15)
        ])
        
        window?.rootViewController = viewController
        window?.makeKeyAndVisible()
    }
    
    @objc private func toggleButtonTapped(_ sender: UIButton) {
        Task { @MainActor in
            isAwake.toggle()
            sender.setTitle(isAwake ? "Awake" : "Asleep", for: .normal)
            FridayState.shared.voiceDetectorActive = isAwake
        }
    }
}

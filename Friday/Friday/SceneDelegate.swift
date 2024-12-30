import UIKit
import AVFoundation

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?
    private var isAwake: Bool = false
    private var gifImageView: UIImageView?  // Keep reference to control animation
    private var patLabel: UILabel?  // Add this for the temporary message
    private var awakeButton: UIButton?  // Add reference to button
    
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
        isLabel.font = .systemFont(ofSize: 18)
        isLabel.textColor = .black
        isLabel.translatesAutoresizingMaskIntoConstraints = false
        
        let button = UIButton(type: .system)
        button.setTitle(isAwake ? "Awake" : "Asleep", for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 18)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.addTarget(self, action: #selector(toggleButtonTapped), for: .touchUpInside)
        self.awakeButton = button  // Store reference
        
        // Create GIF Button instead of ImageView
        let gifButton = UIButton(type: .custom)
        gifButton.translatesAutoresizingMaskIntoConstraints = false
        gifButton.addTarget(self, action: #selector(gifButtonTapped), for: .touchUpInside)
        
        // Create ImageView for the GIF
        let gifImageView = UIImageView()
        gifImageView.contentMode = .scaleAspectFit
        gifImageView.translatesAutoresizingMaskIntoConstraints = false
        self.gifImageView = gifImageView
        
        // Load GIF but start paused
        if let gifPath: String = Bundle.main.path(forResource: "phonograph", ofType: "gif"),
           let gifData: Data = try? Data(contentsOf: URL(fileURLWithPath: gifPath)),
           let gifImage = UIImage.gifImageWithData(gifData) {
            gifImageView.image = gifImage
            gifImageView.layer.speed = 0  // Start paused
        }
        
        // Add GIF to button
        gifButton.addSubview(gifImageView)
        
        // Add observer for recorder state changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFridayStateChange),
            name: .fridayStateChanged,
            object: nil
        )
        
        viewController.view.addSubview(gifButton)
        viewController.view.addSubview(versionLabel)
        viewController.view.addSubview(isLabel)
        viewController.view.addSubview(button)
        
        NSLayoutConstraint.activate([
            // GIF ImageView fills the button
            gifImageView.topAnchor.constraint(equalTo: gifButton.topAnchor),
            gifImageView.bottomAnchor.constraint(equalTo: gifButton.bottomAnchor),
            gifImageView.leadingAnchor.constraint(equalTo: gifButton.leadingAnchor),
            gifImageView.trailingAnchor.constraint(equalTo: gifButton.trailingAnchor),
            
            // Button constraints (replacing old gifImageView constraints)
            gifButton.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            gifButton.bottomAnchor.constraint(equalTo: versionLabel.topAnchor, constant: -20),
            gifButton.widthAnchor.constraint(equalToConstant: 200),
            gifButton.heightAnchor.constraint(equalToConstant: 200),
            
            versionLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            versionLabel.centerYAnchor.constraint(equalTo: viewController.view.centerYAnchor, constant: -50),
            
            isLabel.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            isLabel.topAnchor.constraint(equalTo: versionLabel.bottomAnchor, constant: 11),
            
            button.centerXAnchor.constraint(equalTo: viewController.view.centerXAnchor),
            button.topAnchor.constraint(equalTo: isLabel.bottomAnchor, constant: 10)
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
    
    @objc private func handleFridayStateChange(_ notification: Notification) {
        if let state: String = notification.userInfo?["state"] as? String {
            if state == "voiceRecorder" {
                updateGifAnimation(isRecording: FridayState.shared.voiceRecorderActive)
            } else if state == "voiceDetector" {
                // Update button state when voice detector changes
                Task { @MainActor in
                    isAwake = FridayState.shared.voiceDetectorActive
                    awakeButton?.setTitle(isAwake ? "Awake" : "Asleep", for: .normal)
                }
            }
        }
    }
    
    private func updateGifAnimation(isRecording: Bool) {
        if isRecording {
            gifImageView?.layer.speed = 1  // Play
            gifImageView?.startAnimating()
        } else {
            gifImageView?.layer.speed = 0  // Pause
            gifImageView?.stopAnimating()
        }
    }
    
    @objc private func gifButtonTapped() {
        print("Your cat is patted")
        
        // Create and show temporary label
        let label = UILabel()
        label.text = "Your cat is patted"
        label.textAlignment = .center
        label.textColor = .black
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.alpha = 0  // Start invisible
        label.translatesAutoresizingMaskIntoConstraints = false
        
        guard let gifButton = gifImageView?.superview else { return }
        gifButton.addSubview(label)
        
        // Position above the GIF
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: gifButton.centerXAnchor),
            label.bottomAnchor.constraint(equalTo: gifButton.topAnchor, constant: 30)
        ])
        
        // Animate in and out
        UIView.animate(withDuration: 0.3, animations: {
            label.alpha = 1
        }) { _ in
            // After appearing, wait and fade out
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                UIView.animate(withDuration: 0.3, animations: {
                    label.alpha = 0
                }) { _ in
                    label.removeFromSuperview()
                }
            }
        }
    }
    
    // Keep this for programmatic button control
    func setVoiceDetectorState(_ active: Bool) {
        Task { @MainActor in
            // Update button and state
            isAwake = active
            awakeButton?.setTitle(active ? "Awake" : "Asleep", for: .normal)
            FridayState.shared.voiceDetectorActive = active
        }
    }
}

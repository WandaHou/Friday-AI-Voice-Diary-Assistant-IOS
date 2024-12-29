import UIKit
import AVFoundation
import Speech

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    private var audioRecorder: AudioRecorder?
    private let storageManager = StorageManager()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        setupAudioRecorder()
        return true
    }

    // Support for scenes
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private func setupAudioRecorder() {
        Task { @MainActor in
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                audioRecorder = AudioRecorder(storageManager: storageManager)
                
                // First request microphone permission
                let micPermissionGranted = await withCheckedContinuation { continuation in
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            if granted {
                                print("Microphone access granted")
                            } else {
                                print("Microphone access denied")
                            }
                            continuation.resume(returning: granted)
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            if granted {
                                print("Microphone access granted")
                            } else {
                                print("Microphone access denied")
                            }
                            continuation.resume(returning: granted)
                        }
                    }
                }
                
                // Then request speech recognition permission
                if micPermissionGranted {
                    SFSpeechRecognizer.requestAuthorization { authStatus in
                        if authStatus == .authorized {
                            print("Speech recognition access granted")
                            // Start voice detection only after both permissions granted
                            Task { @MainActor in
                                try? await self.audioRecorder?.startVoiceDetection()
                            }
                        } else {
                            print("Speech recognition access denied")
                        }
                    }
                }
            } catch {
                print("Failed to set up audio session: \(error)")
            }
        }
    }
}

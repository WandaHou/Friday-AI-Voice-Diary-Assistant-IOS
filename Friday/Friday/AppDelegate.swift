import UIKit
import AVFoundation
import Speech

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: App launching")
        
        // Force AudioRecorder initialization
        let _ = AudioRecorder.shared
        print("AppDelegate: AudioRecorder shared instance accessed")
        
        setupAudioSession()
        return true
    }

    // Support for scenes
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    private func setupAudioSession() {
        Task { @MainActor in
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
                
                // Request microphone permission
                let micPermissionGranted = await withCheckedContinuation { @Sendable (continuation: CheckedContinuation<Bool, Never>) in
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            print("Microphone permission: \(granted ? "granted" : "denied")")
                            continuation.resume(returning: granted)
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            print("Microphone permission: \(granted ? "granted" : "denied")")
                            continuation.resume(returning: granted)
                        }
                    }
                }
                
                // If microphone granted, request speech recognition
                if micPermissionGranted {
                    SFSpeechRecognizer.requestAuthorization { status in
                        print("Speech recognition permission: \(status == .authorized ? "granted" : "denied")")
                    }
                }
                
            } catch {
                print("Failed to set up audio session: \(error)")
            }
        }
    }
}

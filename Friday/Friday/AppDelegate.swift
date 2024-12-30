import UIKit
import AVFoundation
import Speech
import UserNotifications

@main
class AppDelegate: UIResponder, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: App launching")
        
        // Force AudioRecorder initialization
        let _ = AudioRecorder.shared
        print("AppDelegate: AudioRecorder shared instance accessed")
        
        // Setup audio session and request permissions
        setupAudioSession()
        
        return true
    }

    private func setupAudioSession() {
        Task { @MainActor in
            do {
                let audioSession = AVAudioSession.sharedInstance()
                try audioSession.setCategory(.playAndRecord,
                                           mode: .default,
                                           options: [.mixWithOthers,         // Allow mixing with other apps
                                                   .allowBluetooth,          // Support Bluetooth devices
                                                   .defaultToSpeaker,        // Use speaker for playback
                                                   .allowBluetoothA2DP])     // Better Bluetooth support
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
                
                // If microphone granted, request other permissions
                if micPermissionGranted {
                    // Request speech recognition permission
                    SFSpeechRecognizer.requestAuthorization { status in
                        print("Speech recognition permission: \(status == .authorized ? "granted" : "denied")")
                        
                        // Request notification permission after speech recognition
                        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
                            if granted {
                                print("AppDelegate: Notification permission granted")
                            } else if let error = error {
                                print("AppDelegate: Failed to request notification permission: \(error.localizedDescription)")
                            }
                        }
                    }
                }
                
            } catch {
                print("Failed to set up audio session: \(error)")
            }
        }
    }
}

import AVFoundation
import UserNotifications
import UIKit

final class AudioSession: AudioSessionProtocol {
    static let shared = AudioSession()
    private let audioSession = AVAudioSession.sharedInstance()
    private var isActive = false
    
    private init() {
        setupNotifications()
    }
    
    func activate() async throws {
        guard !isActive else { return }
        
        // 1. Check permissions
        _ = await PermissionsService.shared.requestMicrophonePermission()
        
        // 2. Configure for optimal compatibility
        try audioSession.setCategory(
            .playAndRecord,
            mode: .spokenAudio,
            options: [
                .mixWithOthers,    // Allow mixing with other apps' audio
                .allowBluetooth,   // Allow Bluetooth devices
                .defaultToSpeaker  // Route audio to speaker by default
            ]
        )
        
        // 3. Activate session
        try audioSession.setActive(true, options: [.notifyOthersOnDeactivation])
        isActive = true
        print("AudioSession: Activated")
    }
    
    func deactivate() {
        guard isActive else { return }
        try? audioSession.setActive(false, options: .notifyOthersOnDeactivation)
        isActive = false
        print("AudioSession: Deactivated")
    }
    
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
    }
    
    @objc private func handleInterruption(_ notification: Notification) {
        NotificationCenter.default.post(
            name: .audioSessionStateChanged,
            object: self,
            userInfo: ["notification": notification]
        )
    }
    
    deinit {
        deactivate()
    }
}

// MARK: - Notifications
extension Notification.Name {
    static let audioSessionStateChanged = Notification.Name("audioSessionStateChanged")
} 
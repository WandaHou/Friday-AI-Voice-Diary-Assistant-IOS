import Foundation  // For URL
import UIKit
import AVFoundation
import UserNotifications

// Protocol for all session types
protocol SessionProtocol {
    func activate() async throws
    func deactivate()
}

// Base class for handling notifications and common functionality
class BaseSession {
    func checkPermissions() async throws {
        // Default implementation
    }
}

// Audio Session Implementation
final class AudioSession: BaseSession, SessionProtocol {
    static let shared = AudioSession()
    private let audioSession = AVAudioSession.sharedInstance()
    
    private var isActive = false
    
    private override init() {
        super.init()
        setupNotifications()
    }
    
    func activate() async throws {
        guard !isActive else { return }
        
        // 1. Check permissions
        _ = await PermissionsService.shared.requestMicrophonePermission()
        
        // 2. Configure for optimal compatibility
        try audioSession.setCategory(.playAndRecord, mode: .spokenAudio, options: [
            .mixWithOthers,         // 1. We want to allow music playing in background
            .allowBluetooth,        // 2. We need microphone access
            .defaultToSpeaker       // 3. We want to continue when screen locks
        ])
//          Category:
//         .mixWithOthers           // Allows mixing with other apps' audio
//         .duckOthers             // Reduces volume of other apps' audio
//         .interruptSpokenAudio    // Interrupts spoken audio from other apps
//         .allowBluetooth         // Allows routing to Bluetooth devices
//         .allowBluetoothA2DP     // Allows high-quality Bluetooth audio
//         .allowAirPlay           // Allows AirPlay devices
//         .defaultToSpeaker       // Routes audio to speaker by default
//         .overrideMutedBehavior  // Plays even when muted

//         Mode:
//         .default        - Standard audio processing
//         .gameChat      - Optimized for game chat
//         .measurement   - Raw audio, minimal processing (best for detection)
//         .moviePlayback - Optimized for video
//         .spokenAudio   - Optimized for speech
//         .videoChat     - Optimized for video calls
//         .voiceChat     - Optimized for voice only

//         Options:
//         .notifyOthersOnDeactivation - Notify other apps when deactivated
//         .duckOthers                 - Reduce volume of other apps' audio
//         .interruptSpokenAudio       - Interrupt spoken audio from other apps
//         .defaultToSpeaker           - Route audio to speaker by default
//         .overrideMutedBehavior      - Play even when muted
        
        // 3. Activate session
        try audioSession.setActive(true, options: [
            .notifyOthersOnDeactivation,
        ])

//         MARK: - Activation Options (AVAudioSession.SetActiveOptions)
//              .notifyOthersOnActivation,             // Tell other apps when we activate
//              .notifyOthersOnDeactivation,           // Tell other apps when we deactivate
//              .prepareToPlayAndRecord,               // Optimize for low latency play/record
//              .interruptSpokenAudioAndMixWithOthers  // Stop spoken audio but allow music

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
        // Handle interruptions
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

// Future sessions can be added here:
/*
final class CameraSession: BaseSession, SessionProtocol {
    // Camera session implementation
}

final class PlaybackSession: BaseSession, SessionProtocol {
    // Audio playback session implementation
}
*/

// MARK: - Notifications
extension Notification.Name {
    static let audioSessionStateChanged = Notification.Name("audioSessionStateChanged")
} 

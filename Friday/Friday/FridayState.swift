import Foundation
import SwiftUI
import UIKit

@MainActor
final class FridayState: ObservableObject {
    static let shared = FridayState()
    private let notificationCenter = NotificationCenter.default
    
    // MARK: - States
    @Published var voiceDetectorActive: Bool = false {
        didSet {
            Task {
                if voiceDetectorActive {
                    try? await AudioRecorder.shared.startListening()
                } else {
                    await AudioRecorder.shared.stopListening()
                }
            }

            print("FridayState: Voice detector state changed to \(voiceDetectorActive)")
            notifyStateChange(.voiceDetectorChanged)
        }
    }
    
    // MARK: - Initialization
    private init() {
        setupNotificationCenter()
    }
    
    // MARK: - Notification Setup
    private func setupNotificationCenter() {
        // Define what notifications this state will post
        print("FridayState: Setting up notification center")
        // Additional setup if needed
    }
    
    private func notifyStateChange(_ notification: FridayNotification) {

        notificationCenter.post(
            name: notification.name,
            object: self,
            userInfo: notification.userInfo
        )
        print("FridayState: Sent notification - \(notification)")
    }
}

// MARK: - Notifications
enum FridayNotification: CustomStringConvertible {
    case voiceDetectorChanged
    
    var description: String {
        switch self {
        case .voiceDetectorChanged:
            return "Voice Detector Changed"
        }
    }
    
    var name: Notification.Name {
        switch self {
        case .voiceDetectorChanged:
            return .fridayVoiceDetectorChanged
        }
    }
    
    var userInfo: [String: Any] {
        switch self {
        case .voiceDetectorChanged:
            return ["type": "voiceDetector"]
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let fridayVoiceDetectorChanged = Notification.Name("fridayVoiceDetectorChanged")
    static let audioLevelChanged = Notification.Name("audioLevelChanged")
    // Add new notification names here in the future:
    // static let fridayNewStateChanged = Notification.Name("fridayNewStateChanged")
}

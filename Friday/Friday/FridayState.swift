import Foundation
import AVFoundation

class FridayState {
    static let shared = FridayState()
    
    var voiceDetectorActive: Bool = false {
        didSet {
            print("FridayState: Voice detector state changed to \(voiceDetectorActive)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .fridayStateChanged,
                    object: nil,
                    userInfo: ["state": "voiceDetector"]
                )
            }
        }
    }
    
    var voiceRecorderActive: Bool = false {
        didSet {
            print("FridayState: Voice recorder state changed to \(voiceRecorderActive)")
            DispatchQueue.main.async {
                NotificationCenter.default.post(
                    name: .fridayStateChanged,
                    object: nil,
                    userInfo: ["state": "voiceRecorder"]
                )
            }
        }
    }
    
    init() {
        // No interruption handling needed
    }
}

extension Notification.Name {
    static let fridayStateChanged = Notification.Name("fridayStateChanged")
} 

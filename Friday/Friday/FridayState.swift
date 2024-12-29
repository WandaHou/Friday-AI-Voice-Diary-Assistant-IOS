import Foundation

class FridayState {
    static let shared = FridayState()
    
    // States - all default to false
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
    
    // Future states will go here:
    // var screenDetectorActive: Bool = false { didSet { ... } }
    // var cameraDetectorActive: Bool = false { didSet { ... } }
    
    private init() {}
}

extension Notification.Name {
    static let fridayStateChanged = Notification.Name("fridayStateChanged")
} 

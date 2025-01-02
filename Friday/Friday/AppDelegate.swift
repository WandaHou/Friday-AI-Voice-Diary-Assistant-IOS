import SwiftUI
import UIKit
class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - Properties
    private let fridayState = FridayState.shared
    
    // MARK: - UIApplicationDelegate
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        print("AppDelegate: Initializing with FridayState")
        return true
    }
    
    // MARK: - State Control
    func setVoiceDetectorState(_ active: Bool) {
        Task { @MainActor in
            fridayState.voiceDetectorActive = active
        }
    }
    
    // MARK: - Permission Helpers
    func checkPermissions() async -> Bool {
        return await PermissionsService.shared.requestAllPermissions()
    }
}

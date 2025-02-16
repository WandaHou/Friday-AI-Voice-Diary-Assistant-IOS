import SwiftUI
import UIKit

class AppDelegate: NSObject, UIApplicationDelegate {
    // MARK: - Properties
    private let permissionsService: PermissionsServiceProtocol
    
    override init() {
        self.permissionsService = PermissionsService.shared
        super.init()
    }
    
    // MARK: - UIApplicationDelegate
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        return true
    }
    
    // MARK: - Permissions
    func checkPermissions() async -> Bool {
        await permissionsService.requestAllPermissions()
    }
}

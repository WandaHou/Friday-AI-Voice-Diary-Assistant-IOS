import SwiftUI
import UIKit

@main
struct FridayApp: App {
    // MARK: - Properties
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    
    // MARK: - Scene
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .task {
                    let setupService = AppSetupService.shared
                    await setupService.setupRequiredDirectories()
                    await setupService.checkInitialPermissions()
                }
        }
    }
}
    
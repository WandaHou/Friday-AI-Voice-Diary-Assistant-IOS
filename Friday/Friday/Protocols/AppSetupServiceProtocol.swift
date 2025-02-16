import Foundation

@MainActor
protocol AppSetupServiceProtocol {
    func setupRequiredDirectories() async
    func checkInitialPermissions() async
} 

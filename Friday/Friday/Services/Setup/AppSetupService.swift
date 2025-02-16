import Foundation
import UIKit

@MainActor
class AppSetupService: AppSetupServiceProtocol {
    static let shared = AppSetupService(
        permissionsService: PermissionsService.shared,
        fileManager: FileManager.default
    )
    
    private let requiredDirectories = ["AudioRecords", "Transcripts", "Diaries"]
    private let permissionsService: PermissionsServiceProtocol
    private let fileManager: FileManagerProtocol
    
    private init(
        permissionsService: PermissionsServiceProtocol,
        fileManager: FileManagerProtocol
    ) {
        self.permissionsService = permissionsService
        self.fileManager = fileManager
    }
    
    func setupRequiredDirectories() async {
        for directoryName in requiredDirectories {
            await setupDirectory(directoryName)
        }
    }
    
    func checkInitialPermissions() async {
        _ = await permissionsService.requestAllPermissions()
    }
    
    private func setupDirectory(_ directoryName: String) async {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("AppSetupService: Failed to get Documents directory")
            return
        }
        
        let directoryPath = documentsPath.appendingPathComponent(directoryName)
        
        if !fileManager.fileExists(atPath: directoryPath.path) {
            do {
                try fileManager.createDirectory(
                    at: directoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("AppSetupService: Created \(directoryName) directory at: \(directoryPath.path)")
            } catch {
                print("AppSetupService: Failed to create \(directoryName) directory: \(error.localizedDescription)")
            }
        } else {
            print("AppSetupService: \(directoryName) directory already exists")
        }
    }
}

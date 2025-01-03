import SwiftUI
import UIKit

@main
struct FridayApp: App {
    // MARK: - Properties
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var fridayState = FridayState.shared
    
    // MARK: - Initialization
    init() {
        let delegate = appDelegate
        Task { @MainActor in
            let _ = await delegate.checkPermissions()
        }
        
        // Setup required directories
        setupAppDirectory("AudioRecords")
        setupAppDirectory("Transcripts")
        setupAppDirectory("Diaries")
        // Add more directories as needed:
        // setupAppDirectory("Images")
        // setupAppDirectory("Videos")
        
        // Create test JSON file
        // createTestJSONFile()
    }
    
    // MARK: - Directory Setup
    private func setupAppDirectory(_ directoryName: String) {
        let fileManager = FileManager.default
        
        // Get Documents directory
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("FridayApp: Failed to get Documents directory")
            return
        }
        
        // Create directory path
        let directoryPath = documentsPath.appendingPathComponent(directoryName)
        
        // Create directory if it doesn't exist
        if !fileManager.fileExists(atPath: directoryPath.path) {
            do {
                try fileManager.createDirectory(
                    at: directoryPath,
                    withIntermediateDirectories: true,
                    attributes: nil
                )
                print("FridayApp: Created \(directoryName) directory at: \(directoryPath.path)")
            } catch {
                print("FridayApp: Failed to create \(directoryName) directory: \(error.localizedDescription)")
            }
        } else {
            print("FridayApp: \(directoryName) directory already exists")
        }
    }
    
    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(fridayState)
                .onAppear {
                    createTestTextFile()  // Create a test text file
                }
        }
    }
}

import AVFoundation
import Speech
import UserNotifications
import UIKit

@MainActor
class PermissionsService: PermissionsServiceProtocol {
    static let shared = PermissionsService()
    
    enum PermissionError: Error {
        case microphone
        case notification
        case speech
    }
    
    private init() {}
    
    func requestMicrophonePermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                print("PermissionsService: Microphone permission \(granted ? "granted" : "denied")")
                continuation.resume(returning: granted)
            }
        }
    }
    
    func requestNotificationPermission() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound])
            print("PermissionsService: Notification permission \(granted ? "granted" : "denied")")
            return granted
        } catch {
            print("PermissionsService: Notification permission error: \(error)")
            return false
        }
    }
    
    func requestSpeechRecognitionPermission() async -> Bool {
        return await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                let granted = status == .authorized
                print("PermissionsService: Speech recognition permission \(granted ? "granted" : "denied")")
                continuation.resume(returning: granted)
            }
        }
    }
    
    func requestAllPermissions() async -> Bool {
        guard await requestNotificationPermission() else {
            print("PermissionsService: Failed to get notification permission")
            return false
        }
        
        guard await requestMicrophonePermission() else {
            print("PermissionsService: Failed to get microphone permission")
            return false
        }
        
        guard await requestSpeechRecognitionPermission() else {
            print("PermissionsService: Failed to get speech recognition permission")
            return false
        }
        
        print("PermissionsService: All permissions granted successfully")
        return true
    }
    
    func checkMicrophonePermission() -> Bool {
        return AVAudioSession.sharedInstance().recordPermission == .granted
    }
    
    func checkNotificationPermission() async -> Bool {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus == .authorized
    }
    
    func checkSpeechRecognitionPermission() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }
    
    func checkAllPermissions() async -> Bool {
        guard await checkNotificationPermission() else { return false }
        guard checkMicrophonePermission() else { return false }
        guard checkSpeechRecognitionPermission() else { return false }
        return true
    }
} 
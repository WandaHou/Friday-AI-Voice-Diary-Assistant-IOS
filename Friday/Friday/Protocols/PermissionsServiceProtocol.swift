import Foundation
import AVFoundation
import Speech

@MainActor
protocol PermissionsServiceProtocol: AnyObject {
    // Check current permission status
    func checkMicrophonePermission() -> Bool
    func checkNotificationPermission() async -> Bool
    func checkSpeechRecognitionPermission() -> Bool
    func checkAllPermissions() async -> Bool
    
    // Request permissions
    func requestMicrophonePermission() async -> Bool
    func requestNotificationPermission() async -> Bool
    func requestSpeechRecognitionPermission() async -> Bool
    func requestAllPermissions() async -> Bool
} 

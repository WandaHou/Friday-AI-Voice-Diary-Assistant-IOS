import Foundation  // For URL
import UIKit
import AVFoundation
import UserNotifications

/// AudioRecorder: A class that handles continuous voice detection and recording
@MainActor
final class AudioRecorder: NSObject, @unchecked Sendable {
    static let shared = AudioRecorder()
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    private let threshold: Float = -25.0
    private var isRecording = false {
        didSet {
            print("AudioRecorder: Recording state changed to: \(isRecording)")
            FridayState.shared.voiceRecorderActive = isRecording
        }
    }
    private var lastRecordingTime: Date?
    private let cooldownInterval: TimeInterval = 1.0
    private var recordingTask: Task<Void, Never>?
    private var isVoiceDetectionActive = false
    private var isShuttingDown = false
    private let silenceThreshold: TimeInterval = 5.0  // 5 seconds of silence
    private let maxRecordingDuration: TimeInterval = 2 * 3600.0  // hours * 3600 seconds
    private var lastVoiceDetectionTime: Date?
    private var silenceCheckTask: Task<Void, Never>?
    
    // MARK: - Errors
    enum AudioRecorderError: LocalizedError {
        case recordingInProgress
        case audioSessionSetupFailed
        case recordingSetupFailed
        case microphonePermissionDenied
        
        var errorDescription: String? {
            switch self {
            case .recordingInProgress:
                return "AudioRecorder: Recording is already in progress"
            case .audioSessionSetupFailed:
                return "AudioRecorder: Failed to setup audio session"
            case .recordingSetupFailed:
                return "AudioRecorder: Failed to setup recording"
            case .microphonePermissionDenied:
                return "AudioRecorder: Microphone permission is required"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        print("AudioRecorder: Creating shared instance")
        super.init()
        
        print("AudioRecorder: Setting up state observation")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFridayStateChange),
            name: .fridayStateChanged,
            object: nil
        )
        
        // Add audio session interruption observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil
        )
        
        print("AudioRecorder: Observer setup complete")
        setupAudioSession()
        
        // Check initial state
        Task { @MainActor in
            await updateVoiceDetection()
        }
        print("AudioRecorder: Initialization complete")
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("AudioRecorder: Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Permissions
    private func checkMicrophonePermission() async throws {
        let status = await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        
        guard status else {
            throw AudioRecorderError.microphonePermissionDenied
        }
    }
    
    // MARK: - Voice Detection
    func startVoiceDetection() async throws {
        guard !isVoiceDetectionActive else { return }
        try await checkMicrophonePermission()
        
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        // Ensure we're not adding multiple taps
        inputNode.removeTap(onBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            guard let self = self, !self.isShuttingDown else { return }
            
            Task { @MainActor [weak self] in
                guard let self = self, !self.isShuttingDown else { return }
                let level = self.calculateDecibels(buffer: buffer)
                if level > self.threshold && !self.isRecording && self.canStartNewRecording() {
                    print("================================================")
                    print("AudioRecorder: Voice activity detected at \(Date().formatted(date: .omitted, time: .standard))! Level: \(level) dB")
                    //print("================================================")
                    await self.handleVoiceDetection()
                }
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isVoiceDetectionActive = true
            print("AudioRecorder: Voice detection started")
        } catch {
            isVoiceDetectionActive = false
            print("AudioRecorder: Failed to start audio engine: \(error)")
            FridayState.shared.voiceDetectorActive = false
            throw AudioRecorderError.audioSessionSetupFailed
        }
    }
    
    private func canStartNewRecording() -> Bool {
        guard let lastRecording = lastRecordingTime else { return true }
        return Date().timeIntervalSince(lastRecording) >= cooldownInterval
    }
    
    private func handleVoiceDetection() async {
        guard !isRecording, !isShuttingDown else { return }
        
        do {
            try await startRecording()
            lastRecordingTime = Date()
            lastVoiceDetectionTime = Date()
            
            // Start monitoring for silence
            startSilenceMonitoring()
        } catch {
            print("AudioRecorder: Failed to start recording: \(error.localizedDescription)")
        }
    }
    
    private func startSilenceMonitoring() {
        // Cancel any existing silence monitoring task
        silenceCheckTask?.cancel()
        
        // Create new task to monitor silence
        silenceCheckTask = Task {
            while !Task.isCancelled && isRecording {
                // Check if we've exceeded the silence threshold
                if let lastVoiceTime = lastVoiceDetectionTime,
                   Date().timeIntervalSince(lastVoiceTime) >= silenceThreshold {
                    await stopRecording()
                    break
                }
                
                try? await Task.sleep(nanoseconds: 1_000_000_000) // Check every second
            }
        }
    }
    
    // MARK: - Audio Processing
    private func calculateDecibels(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { return -160.0 }
        
        let frameLength = UInt(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            let sample = channelData[Int(i)]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        let db = 20 * log10(max(rms, Float.leastNonzeroMagnitude))
        
        // If we detect voice activity, update the last voice detection time
        if db > threshold {
            lastVoiceDetectionTime = Date()
        }
        
        return db
    }
    
    // MARK: - Recording Management
    private func getAudioDirectory() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDirectory = documentsPath.appendingPathComponent("AudioRecordings")
        
        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(at: audioDirectory, withIntermediateDirectories: true)
        
        return audioDirectory
    }
    
    func startRecording() async throws {
        guard !isRecording else {
            throw AudioRecorderError.recordingInProgress
        }
        
        guard !isShuttingDown else { return }
        
        // Cancel any existing recording task
        recordingTask?.cancel()
        recordingTask = nil
        
        do {
            try audioSession.setCategory(.playAndRecord,
                                       mode: .default,
                                       options: [.mixWithOthers])
            try audioSession.setActive(true)
            
            // Use AudioRecordings directory
            let audioDirectory = getAudioDirectory()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd-HH-mm-ss"
            let timestamp = dateFormatter.string(from: Date())
            let audioFilename = audioDirectory.appendingPathComponent("recording-\(timestamp).m4a")
            
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 12000,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.medium.rawValue
            ]
            
            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            
            guard let recorder = audioRecorder, recorder.record() else {
                throw AudioRecorderError.recordingSetupFailed
            }
            
            isRecording = true
            print("AudioRecorder: Started recording to: \(audioFilename.lastPathComponent)")
            
            // Start a new recording task
            recordingTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self!.maxRecordingDuration * 1_000_000_000))
                if !Task.isCancelled {
                    await self?.stopRecording()
                }
            }
        } catch {
            isRecording = false
            print("AudioRecorder: Recording setup failed: \(error.localizedDescription)")
            
            // Add this: If recording fails, we should stop voice detection entirely
            if error._domain == "NSOSStatusErrorDomain" {  // This indicates system-level audio issues
                print("AudioRecorder: System audio conflict detected - stopping voice detection")
                Task { @MainActor in
                    await stopVoiceDetection()  // This will update FridayState
                    
                    // Notify user after 5 seconds
                    DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                        let content = UNMutableNotificationContent()
                        content.title = "Voice Detection Stopped"
                        content.body = "Hey, you wanna come back to turn me on?"
                        content.sound = .default
                        
                        let request = UNNotificationRequest(
                            identifier: "voiceDetectionStopped",
                            content: content,
                            trigger: nil
                        )
                        
                        UNUserNotificationCenter.current().add(request) { error in
                            if let error = error {
                                print("AudioRecorder: Failed to schedule notification: \(error)")
                            }
                        }
                    }
                }
            }
            
            throw AudioRecorderError.recordingSetupFailed
        }
    }
      
      func stopRecording() async {
          silenceCheckTask?.cancel()
          silenceCheckTask = nil
          lastVoiceDetectionTime = nil
          
          if let recorder = audioRecorder {
              recorder.stop()
              print("AudioRecorder: Recording saved successfully at \(recorder.url.lastPathComponent)")
              print("================================================")
              
          }
          
          audioRecorder = nil
          isRecording = false
      }
    
    // MARK: - Cleanup
    func stopVoiceDetection() async {
        guard isVoiceDetectionActive else { return }
        
        print("AudioRecorder: Stopping voice detection...")
        await stopRecording()
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        isVoiceDetectionActive = false
        FridayState.shared.voiceDetectorActive = false
        print("AudioRecorder: Voice detection stopped")
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        recordingTask?.cancel()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioRecorder?.stop()
        FridayState.shared.voiceDetectorActive = false
        print("AudioRecorder: AudioRecorder deinitialized")
    }
    
    @objc private func handleFridayStateChange(_ notification: Notification) {
        print("AudioRecorder: State change detected")
        Task { @MainActor in
            await updateVoiceDetection()
        }
    }
    
    private func updateVoiceDetection() async {
        if FridayState.shared.voiceDetectorActive {
            print("AudioRecorder: Activating voice detection")
            do {
                try await startVoiceDetection()
            } catch {
                print("AudioRecorder: Failed to start voice detection: \(error)")
                FridayState.shared.voiceDetectorActive = false
            }
        } else {
            print("AudioRecorder: Stopping voice detection")
            await stopVoiceDetection()
        }
    }
    
    @objc private func handleAudioSessionInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        if type == .began {
            print("AudioRecorder: Audio session interrupted")
            Task { @MainActor in
                await stopVoiceDetection()  // This will update FridayState
                
                // Schedule notification after 5 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                    let content = UNMutableNotificationContent()
                    content.title = "Voice Detection Stopped"
                    content.body = "Hey, you wanna come back to turn me on?"
                    content.sound = .default
                    
                    let request = UNNotificationRequest(
                        identifier: "voiceDetectionStopped",
                        content: content,
                        trigger: nil
                    )
                    
                    UNUserNotificationCenter.current().add(request) { error in
                        if let error = error {
                            print("AudioRecorder: Failed to schedule notification: \(error)")
                        }
                    }
                }
            }
        }
    }
}

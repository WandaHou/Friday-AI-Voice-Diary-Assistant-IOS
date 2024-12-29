import Foundation  // For URL
import UIKit
import AVFoundation

/// AudioRecorder: A class that handles continuous voice detection and recording
@MainActor
final class AudioRecorder: NSObject, @unchecked Sendable {
    static let shared = AudioRecorder()
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private var audioRecorder: AVAudioRecorder?
    private let audioSession = AVAudioSession.sharedInstance()
    private let threshold: Float = -30.0
    private var isRecording = false {
        didSet {
            print("Recording state changed to: \(isRecording)")
            FridayState.shared.voiceRecorderActive = isRecording
        }
    }
    private var lastRecordingTime: Date?
    private let cooldownInterval: TimeInterval = 1.0
    private var recordingTask: Task<Void, Never>?
    private var isVoiceDetectionActive = false
    private var isShuttingDown = false
    private let storageManager: AudioStorageManaging
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
                return "Recording is already in progress"
            case .audioSessionSetupFailed:
                return "Failed to setup audio session"
            case .recordingSetupFailed:
                return "Failed to setup recording"
            case .microphonePermissionDenied:
                return "Microphone permission is required"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        print("AudioRecorder: Creating shared instance")
        self.storageManager = StorageManager()
        super.init()
        
        print("AudioRecorder: Setting up state observation")
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleFridayStateChange),
            name: .fridayStateChanged,
            object: nil
        )
        print("AudioRecorder: Observer setup complete")
        
        setupAudioSession()
        setupNotifications()
        
        // Check initial state
        Task { @MainActor in
            await updateVoiceDetection()
        }
        print("AudioRecorder: Initialization complete")
    }
    
    // MARK: - Audio Session Setup
    private func setupAudioSession() {
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth, .mixWithOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            // Add this line for background operation
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to setup audio session: \(error.localizedDescription)")
        }
    }
    
    // Add handling for audio interruptions
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioSessionInterruption),
            name: AVAudioSession.interruptionNotification,
            object: nil)
    }
    
    @objc private func handleAudioSessionInterruption(notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            Task { await stopRecording() }
        case .ended:
            guard let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt,
                  AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) else {
                return
            }
            // Optionally restart voice detection
            try? await startVoiceDetection()
        @unknown default:
            break
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
                    print("Voice activity detected! Level: \(level) dB")
                    await self.handleVoiceDetection()
                }
            }
        }
        
        do {
            audioEngine.prepare()
            try audioEngine.start()
            isVoiceDetectionActive = true
            print("Voice detection started")
        } catch {
            isVoiceDetectionActive = false
            print("Failed to start audio engine: \(error)")
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
            print("Failed to start recording: \(error.localizedDescription)")
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
            try audioSession.setCategory(.record, mode: .default)
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
            print("Started recording to: \(audioFilename.lastPathComponent)")
            
            // Start a new recording task
            recordingTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(self!.maxRecordingDuration * 1_000_000_000))
                if !Task.isCancelled {
                    await self?.stopRecording()
                }
            }
        } catch {
            isRecording = false
            print("Recording setup failed: \(error.localizedDescription)")
            throw AudioRecorderError.recordingSetupFailed
        }
    }
      
      func stopRecording() async {
          silenceCheckTask?.cancel()
          silenceCheckTask = nil
          lastVoiceDetectionTime = nil
          
          if let recorder = audioRecorder {
              recorder.stop()
              print("Recording stopped: \(recorder.url.lastPathComponent)")
              
              // Notify StorageManager to transcribe
              Task {
                  try? await storageManager.transcribeAudioFile(at: recorder.url)
              }
          }
          
          audioRecorder = nil
          isRecording = false
      }
    
    // MARK: - Cleanup
    func pauseVoiceDetection() async {
        guard isVoiceDetectionActive else { return }
        
        print("Pausing voice detection...")
        
        // Stop current recording if any
        await stopRecording()
        
        // Pause voice detection
        if isVoiceDetectionActive {
            audioEngine.pause()  // Use pause instead of stop
            audioEngine.inputNode.removeTap(onBus: 0)
            isVoiceDetectionActive = false
            print("Voice detection paused")
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        recordingTask?.cancel()
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        audioRecorder?.stop()
        print("AudioRecorder deinitialized")
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
                print("Failed to start voice detection: \(error)")
            }
        } else {
            print("AudioRecorder: Pausing voice detection")
            await pauseVoiceDetection()  // Use pause instead of cleanup
        }
    }
}

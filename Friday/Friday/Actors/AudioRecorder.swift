import Foundation
import AVFoundation
import UIKit

/// An actor that handles voice detection and recording functionality
actor AudioRecorder: AudioRecorderProtocol {
    // MARK: - Singleton
    static let shared = AudioRecorder()
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private let audioSession: AudioSessionProtocol
    private let transcriptionService: WhisperServiceProtocol
    private let fileManager: FileManagerProtocol
    private var audioRecorder: AVAudioRecorder?
    private var isListening = false
    private var isRecording = false
    let threshold: Float = -25.0  // Voice detection threshold
    private let silenceThreshold: TimeInterval = 5.0
    private var lastVoiceDetectionTime: Date?
    private var silenceCheckTask: Task<Void, Never>?
    
    // MARK: - Recording Properties
    private var recordingStartTime: Date?
    private var recordingFilename: String?
    
    private var currentLevel: Float = -160.0
    
    // Public accessor for audio level
    var currentAudioLevel: Float? {
        get async {
            guard isListening else { return nil }
            return currentLevel
        }
    }
    
    // MARK: - Initialization
    init(
        audioSession: AudioSessionProtocol = AudioSession.shared,
        transcriptionService: WhisperServiceProtocol = WhisperService.shared,
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        self.audioSession = audioSession
        self.transcriptionService = transcriptionService
        self.fileManager = fileManager
    }
    
    // MARK: - Public Interface
    /// Starts voice detection with the audio engine
    func startListening() async throws {
        guard !isListening else { return }
        
        // 1. Setup audio session
        try await audioSession.activate()
        
        // 2. Configure audio engine
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        
        // 3. Install tap for voice detection
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            Task { [weak self] in
                await self?.processSoundBuffer(buffer)
            }
        }
        
        // 4. Start engine
        try audioEngine.start()
        isListening = true
        print("AudioRecorder: Started listening")
    }
    
    /// Stops voice detection
    func stopListening() {
        guard isListening else { return }
        
        // 1. Stop and cleanup audio engine
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        // 2. Deactivate audio session
        audioSession.deactivate()
        
        isListening = false
        
        // Ensure we stop any ongoing recording
        if isRecording {
            Task {
                await stopRecording()
            }
        }
        print("AudioRecorder: Voice detection stopped")
    }
    
    // MARK: - Private Methods
    private func processSoundBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isListening else { return }
        
        let level = calculateDecibels(buffer)
        currentLevel = level  // Store current level
        
        if level > threshold {
            lastVoiceDetectionTime = Date()
            if !isRecording {
                Task {
                    try await startRecording()
                }
            }
        }
        
        if isRecording {
            checkSilence()
        }
    }
    
    private func calculateDecibels(_ buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0],
              buffer.frameLength > 0 else { return -160.0 }
        
        let frameLength = UInt(buffer.frameLength)
        var sum: Float = 0
        
        for i in 0..<frameLength {
            let sample = channelData[Int(i)]
            sum += sample * sample
        }
        
        let rms = sqrt(sum / Float(frameLength))
        return 20 * log10(max(rms, Float.leastNonzeroMagnitude))
    }
    
    private func startRecording() async throws {
        guard !isRecording else { return }
        
        // Setup recording format
        let recordingURL = try createNewRecordingURL()
        
        // Update settings for WAV format
        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 44100.0,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsFloatKey: false,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]
        
        // Create and start recorder
        audioRecorder = try AVAudioRecorder(url: recordingURL, settings: settings)
        audioRecorder?.record()
        
        recordingStartTime = Date()
        isRecording = true
        print("AudioRecorder: Started recording at \(recordingURL.lastPathComponent)")
    }
    
    private func createNewRecordingURL() throws -> URL {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw RecordingError.fileCreationFailed
        }
        
        let audioRecordsPath = documentsPath.appendingPathComponent("AudioRecords")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let startTimeString = dateFormatter.string(from: Date())
        
        return audioRecordsPath.appendingPathComponent("\(startTimeString)_recording.wav")
    }
    
    private func checkSilence() {
        guard let lastVoiceTime = lastVoiceDetectionTime else { return }
        
        // Only create a new task if one isn't already running
        if silenceCheckTask == nil && Date().timeIntervalSince(lastVoiceTime) >= silenceThreshold {
            silenceCheckTask = Task {
                await stopRecording()
                silenceCheckTask = nil
            }
        }
    }
    
    private func stopRecording() async {
        guard let recorder = audioRecorder else { return }
        
        recorder.stop()
        
        do {
            // Just transcribe - WhisperService will handle cleanup
            _ = try await transcriptionService.transcribeSingleFile(recorder.url)
        } catch {
            print("AudioRecorder: Failed to process recording: \(error)")
        }
        
        // Cleanup recording state
        audioRecorder = nil
        recordingStartTime = nil
        isRecording = false
        URLCache.shared.removeAllCachedResponses() // clean cache files
    }
    
    // Error handling
    enum RecordingError: Error {
        case fileCreationFailed
    }
    
    private func getRecordingURL() -> URL? {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        
        let audioDirectory = documentsPath.appendingPathComponent("AudioRecords")
        let filename = "\(timestamp).wav"
        return audioDirectory.appendingPathComponent(filename)
    }
}

// Helper extension
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

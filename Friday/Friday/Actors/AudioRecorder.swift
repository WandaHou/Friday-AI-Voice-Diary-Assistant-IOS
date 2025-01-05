import Foundation
import AVFoundation
import UIKit

/// An actor that handles voice detection and recording functionality
actor AudioRecorder {
    // MARK: - Singleton
    static let shared = AudioRecorder()
    
    // MARK: - Properties
    private let audioEngine = AVAudioEngine()
    private var audioSession: AudioSession?
    private var audioRecorder: AVAudioRecorder?
    private var isListening = false
    private var isRecording = false
    let threshold: Float = -40.0  // Voice detection threshold
    private let silenceThreshold: TimeInterval = 5.0
    private var lastVoiceDetectionTime: Date?
    private var silenceCheckTask: Task<Void, Never>?
    
    // MARK: - Recording Properties
    private var recordingStartTime: Date?
    
    private var currentLevel: Float = -160.0
    
    // Public accessor for audio level
    var currentAudioLevel: Float? {
        get async {
            guard isListening else { return nil }
            return currentLevel
        }
    }
    
    // MARK: - Initialization
    private init() {}
    
    // MARK: - Public Interface
    /// Starts voice detection with the audio engine
    func startListening() async throws {
        guard !isListening else { return }
        
        // 1. Setup audio session
        audioSession = AudioSession.shared
        try await audioSession?.activate()
        
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
        
        // 2. Cleanup audio session
        audioSession = nil
        
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
        // let format = audioEngine.inputNode.outputFormat(forBus: 0)
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
        
        if Date().timeIntervalSince(lastVoiceTime) >= silenceThreshold {
            Task {
                await stopRecording()
            }
        }
    }
    
    private func stopRecording() async {
        guard isRecording,
              let recorder = audioRecorder,
              let startTime = recordingStartTime else { return }
        
        recorder.stop()
        
        // Format start time with full date
        let startFormatter = DateFormatter()
        startFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let startTimeString = startFormatter.string(from: startTime)
        
        // Format end time with only time
        let endFormatter = DateFormatter()
        endFormatter.dateFormat = "HH-mm-ss"
        let endTimeString = endFormatter.string(from: Date())
        
        let oldURL = recorder.url
        let newURL = oldURL.deletingLastPathComponent().appendingPathComponent(
            "\(startTimeString)_to_\(endTimeString).wav"
        )
        
        do {
            try FileManager.default.moveItem(at: oldURL, to: newURL)
            print("AudioRecorder: Saved recording to \(newURL.lastPathComponent)")
            
            // Schedule transcription after a delay
            Task {
                do {
                    if #available(iOS 16.0, *) {
                        try await Task.sleep(for: .seconds(silenceThreshold))
                    } else {
                        // Fallback on earlier versions
                    }
                    print("Starting transcription for newly saved recording...")
                    guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
                        print("Failed to get documents path")
                        return
                    }
                    let audioPath = documentsPath.appendingPathComponent("AudioRecords")
                    _ = try await WhisperService.shared.transcribeAudioFiles(in: audioPath)
                } catch {
                    print("Transcription failed: \(error)")
                }
            }
        } catch {
            print("AudioRecorder: Failed to rename recording: \(error)")
        }
        
        // Cleanup
        audioRecorder = nil
        recordingStartTime = nil
        isRecording = false
    }
    
    // Error handling
    enum RecordingError: Error {
        case fileCreationFailed
    }
}

// Helper extension
extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

import Foundation
import AVFoundation
import Speech

protocol AudioStorageManaging: Actor {
    func transcribeAudioFile(at url: URL) async throws
    func getAllRecordings() async throws -> [(audio: URL, transcript: URL?)]
    func deleteRecording(fileName: String) async throws
    func getTranscript(for fileName: String) async throws -> String?
    func getStorageInfo() async -> (audioSize: Int64, transcriptSize: Int64)
}

enum StorageError: LocalizedError {
    case iCloudBackupInProgress
    case lowDeviceStorage
    case transcriptionFailed(Error)
    
    var errorDescription: String? {
        switch self {
        case .iCloudBackupInProgress:
            return "Cannot save while iCloud backup is in progress"
        case .lowDeviceStorage:
            return "Device storage is running low"
        case .transcriptionFailed(let error):
            return "Transcription failed: \(error.localizedDescription)"
        }
    }
}

actor StorageManager: AudioStorageManaging {
    // MARK: - Properties
    private let speechRecognizer: SFSpeechRecognizer? = {
        let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        if recognizer != nil {
            print("Speech recognizer initialized successfully")
        } else {
            print("Error: Speech recognizer could not be initialized")
        }
        return recognizer
    }()
    
    private nonisolated lazy var baseDirectory: URL = {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }()
    
    private nonisolated lazy var audioDirectory: URL = {
        let audioPath = baseDirectory.appendingPathComponent("AudioRecordings")
        try? FileManager.default.createDirectory(at: audioPath, withIntermediateDirectories: true)
        return audioPath
    }()
    
    private nonisolated lazy var transcriptDirectory: URL = {
        let transcriptPath = baseDirectory.appendingPathComponent("Transcripts")
        try? FileManager.default.createDirectory(at: transcriptPath, withIntermediateDirectories: true)
        return transcriptPath
    }()
    
    // MARK: - Initialization
    init() {
        setupDirectories()
    }
    
    private nonisolated func setupDirectories() {
        let paths = [audioDirectory, transcriptDirectory]
        for path in paths {
            if !FileManager.default.fileExists(atPath: path.path) {
                try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            }
        }
    }
    
    // MARK: - Audio File Management
    func transcribeAudioFile(at url: URL) async throws {
        let fileName = url.deletingPathExtension().lastPathComponent
        await transcribeAudioFile(url: url, fileName: fileName)
    }
    
    private func checkSpeechPermission() async throws {
        let status = SFSpeechRecognizer.authorizationStatus()
        guard status == .authorized else {
            throw StorageError.transcriptionFailed(
                NSError(domain: "Speech", code: -1,
                       userInfo: [NSLocalizedDescriptionKey: "Speech recognition permission denied"])
            )
        }
    }
    
    private func transcribeAudioFile(url: URL, fileName: String) async {
        do {
            try await checkSpeechPermission()
            
            guard let speechRecognizer = speechRecognizer else {
                print("Speech recognizer not available")
                return
            }
            
            let request = SFSpeechURLRecognitionRequest(url: url)
            // Explicitly disable local recognition
            request.requiresOnDeviceRecognition = false
            request.shouldReportPartialResults = false
            print("Using cloud recognition")
            
            let transcription = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<SFSpeechRecognitionResult, Error>) in
                _ = speechRecognizer.recognitionTask(with: request) { result, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let result = result, result.isFinal else { return }
                    continuation.resume(returning: result)
                }
            }
            
            let dateString = fileName.replacingOccurrences(of: "recording-", with: "")
            
            let transcriptFileName = "transcribed-\(dateString)"
            let transcriptURL = transcriptDirectory.appendingPathComponent("\(transcriptFileName).txt")
            
            let transcriptionText = transcription.bestTranscription.formattedString
            try transcriptionText.write(to: transcriptURL, atomically: true, encoding: .utf8)
            print("Transcription saved: \(transcriptFileName)")
            
        } catch {
            print("Transcription failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - File Retrieval
    func getAllRecordings() async throws -> [(audio: URL, transcript: URL?)] {
        let audioFiles = try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "m4a" }
        
        return audioFiles.map { audioURL in
            let fileName = audioURL.deletingPathExtension().lastPathComponent
            let transcriptURL = transcriptDirectory.appendingPathComponent("\(fileName).txt")
            return (audio: audioURL, transcript: FileManager.default.fileExists(atPath: transcriptURL.path) ? transcriptURL : nil)
        }
    }
    
    // MARK: - File Deletion
    func deleteRecording(fileName: String) async throws {
        let audioURL = audioDirectory.appendingPathComponent("\(fileName).m4a")
        let transcriptURL = transcriptDirectory.appendingPathComponent("\(fileName).txt")
        
        if FileManager.default.fileExists(atPath: audioURL.path) {
            try FileManager.default.removeItem(at: audioURL)
        }
        
        if FileManager.default.fileExists(atPath: transcriptURL.path) {
            try FileManager.default.removeItem(at: transcriptURL)
        }
    }
    
    // MARK: - Utilities
    func getTranscript(for fileName: String) async throws -> String? {
        let transcriptURL = transcriptDirectory.appendingPathComponent("\(fileName).txt")
        guard FileManager.default.fileExists(atPath: transcriptURL.path) else { return nil }
        return try String(contentsOf: transcriptURL, encoding: .utf8)
    }
    
    func getStorageInfo() async -> (audioSize: Int64, transcriptSize: Int64) {
        var audioSize: Int64 = 0
        var transcriptSize: Int64 = 0
        
        do {
            let audioFiles = try FileManager.default.contentsOfDirectory(at: audioDirectory, includingPropertiesForKeys: [.fileSizeKey])
            let transcriptFiles = try FileManager.default.contentsOfDirectory(at: transcriptDirectory, includingPropertiesForKeys: [.fileSizeKey])
            
            audioSize = try audioFiles.reduce(Int64(0)) {
                $0 + Int64(try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            }
            transcriptSize = try transcriptFiles.reduce(Int64(0)) {
                $0 + Int64(try $1.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0)
            }
        } catch {
            print("Error calculating storage size: \(error.localizedDescription)")
        }
        
        return (audioSize, transcriptSize)
    }
}

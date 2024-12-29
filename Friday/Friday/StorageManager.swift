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
    private let speechRecognizers: [SFSpeechRecognizer?] = [
        SFSpeechRecognizer(locale: Locale(identifier: "en-US")),  // Try English first
        SFSpeechRecognizer(locale: Locale(identifier: "zh-CN")),  // Then Chinese
        // Add more languages here in the future, they will be tried in order
        // SFSpeechRecognizer(locale: Locale(identifier: "ja-JP")),  // Example: Japanese
        // SFSpeechRecognizer(locale: Locale(identifier: "ko-KR")),  // Example: Korean
    ]
    
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
        // Print available recognizers in order
        print("\n=== Speech Recognizers (in order) ===")
        for (index, recognizer) in speechRecognizers.enumerated() {
            if let locale = recognizer?.locale {
                print("\(index + 1). \(locale.identifier)")
            }
        }
        print("================================\n")
        
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
            
            // Try each recognizer in order
            for recognizer in speechRecognizers {
                guard let speechRecognizer = recognizer else { continue }
                
                do {
                    let transcription = try await transcribeWith(recognizer: speechRecognizer, url: url)
                    print("Successfully transcribed using \(speechRecognizer.locale.identifier)")
                    await saveTranscription(transcription, fileName: fileName)
                    return
                } catch {
                    print("Failed with \(speechRecognizer.locale.identifier), trying next...")
                    // Don't print "Skipping transcription" here, just continue to next recognizer
                    continue
                }
            }
            
            // Only print skip message if all recognizers failed
            print("Skipping transcription - all recognizers failed")
            
        } catch {
            print("Transcription permission error: \(error.localizedDescription)")
        }
    }
    
    private func transcribeWith(recognizer: SFSpeechRecognizer, url: URL) async throws -> SFSpeechRecognitionResult {
        let request = SFSpeechURLRecognitionRequest(url: url)
        request.shouldReportPartialResults = false
        request.requiresOnDeviceRecognition = false  // Force cloud only
        
        return try await withCheckedThrowingContinuation { continuation in
            _ = recognizer.recognitionTask(with: request) { result, error in
                if error != nil {
                    // Don't print skip message here, let the caller handle it
                    continuation.resume(throwing: NSError(domain: "Speech", code: -1))
                    return
                }
                
                guard let result = result, result.isFinal else { return }
                continuation.resume(returning: result)
            }
        }
    }
    
    private func saveTranscription(_ transcription: SFSpeechRecognitionResult, fileName: String) async {
        let transcriptFileName = "transcribed-\(fileName)"
        let transcriptURL = transcriptDirectory.appendingPathComponent("\(transcriptFileName).txt")
        try? transcription.bestTranscription.formattedString.write(to: transcriptURL, atomically: true, encoding: .utf8)
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

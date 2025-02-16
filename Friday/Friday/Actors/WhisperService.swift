import Foundation
import UIKit

actor WhisperService: WhisperServiceProtocol {
    static let shared = WhisperService()
    private let fileManager: FileManagerProtocol
    private let apiKey: String
    
    init(fileManager: FileManagerProtocol = FileManager.default) {
        self.fileManager = fileManager
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API key not found")
        }
        self.apiKey = key
    }
    
    func transcribeAudioFiles(in directory: URL) async throws -> String {
        print("WhisperService: Scanning directory: \(directory.path)")
        
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: []
        )
        .filter { $0.pathExtension == "wav" }
        .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        print("WhisperService: Found \(contents.count) WAV files")
        
        guard !contents.isEmpty else {
            print("WhisperService: No audio files found to transcribe")
            return "No audio files to transcribe"
        }
        
        var fullTranscript = ""
        
        for audioFile in contents {
            print("WhisperService: Processing file: \(audioFile.lastPathComponent)")
            let transcript = try await transcribeSingleFile(audioFile)
            fullTranscript += "\(transcript)\n\n"
            print("WhisperService: Completed processing: \(audioFile.lastPathComponent)")
        }
        
        return fullTranscript
    }
    
    func transcribeSingleFile(_ file: URL) async throws -> String {
        let transcript = try await transcribeAudio(file: file)
        try await saveTranscript(transcript, filename: file.lastPathComponent)
        
        // Remove the audio file and clear temporary files
        try fileManager.removeItem(at: file)
        
        return transcript
    }
    
    private func transcribeAudio(file: URL) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/audio/transcriptions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let boundary = UUID().uuidString
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var data = Data()
        // Add audio file
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(file.lastPathComponent)\"\r\n")
        data.append("Content-Type: audio/wav\r\n\r\n")
        data.append(try Data(contentsOf: file))
        data.append("\r\n")
        
        // Add model parameter
        data.append("--\(boundary)\r\n")
        data.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n")
        data.append("whisper-1\r\n")
        data.append("--\(boundary)--\r\n")
        
        request.httpBody = data
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(WhisperResponse.self, from: responseData)
        
        return response.text
    }
    
    private func extractDate(from filename: String) -> String {
        // Example filename format: "2024-03-21_14-30-45_recording.wav"
        let components = filename.components(separatedBy: "_")
        if components.count >= 2 {
            return components[0]  // "2024-03-21"
        }
        return "unknown_date"
    }
    
    private func extractTime(from filename: String) -> String {
        // Example filename format: "2024-03-21_14-30-45_recording.wav"
        let components = filename.components(separatedBy: "_")
        if components.count >= 2 {
            // Convert from "14-30-45" to "14:30:45"
            return components[1].replacingOccurrences(of: "-", with: ":")
        }
        return "unknown_time"
    }
    
    private func saveTranscript(_ text: String, filename: String) async throws {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }
        
        let transcriptsPath = documentsPath.appendingPathComponent("Transcripts")
        let transcriptURL = transcriptsPath.appendingPathComponent("\(extractDate(from: filename)).txt")
        print("Saving transcript to: \(transcriptURL.path)")
        
        // Format the new transcript with time
        let time = extractTime(from: filename)
        let formattedTranscript = """
        At \(time):
        \(text)
        
        """
        
        if fileManager.fileExists(atPath: transcriptURL.path) {
            let existingContent = try String(contentsOf: transcriptURL, encoding: .utf8)
            let updatedContent = existingContent + "\n" + formattedTranscript
            try updatedContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        } else {
            try formattedTranscript.write(to: transcriptURL, atomically: true, encoding: .utf8)
        }
    }
    
}

// MARK: - Models
struct WhisperResponse: Codable {
    let text: String
}

enum TranscriptionError: Error {
    case saveFailed
}

extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}

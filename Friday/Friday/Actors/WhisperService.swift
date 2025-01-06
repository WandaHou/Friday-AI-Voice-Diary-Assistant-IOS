import Foundation

actor WhisperService {
    static let shared = WhisperService()
    private let apiKey: String
    private let fileManager = FileManager.default
    
    private init() {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API key not found")
        }
        self.apiKey = key
    }
    
    func transcribeAudioFiles(in directory: URL) async throws -> String {
        let contents = try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "wav" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
        
        guard !contents.isEmpty else { return "No audio files to transcribe" }
        
        var fullTranscript = ""
        var lastFileDate: String?
        
        for audioFile in contents {
            let transcript = try await transcribeAudio(file: audioFile)
            let timeRange = extractTimeRange(from: audioFile.lastPathComponent)
            fullTranscript += "At \(timeRange.start):\n\(transcript)\n\n"
            lastFileDate = extractDate(from: audioFile.lastPathComponent)
            
            try? fileManager.removeItem(at: audioFile)
        }
        
        if !fullTranscript.isEmpty {
            try await saveTranscript(fullTranscript, date: lastFileDate ?? "unknown_date")
        }
        
        return fullTranscript
    }
    
    func transcribeSingleFile(_ file: URL) async throws -> String {
        let transcript = try await transcribeAudio(file: file)
        let timeRange = extractTimeRange(from: file.lastPathComponent)
        let formattedTranscript = "At \(timeRange.start):\n\(transcript)\n\n"
        
        try? fileManager.removeItem(at: file)
        
        try await saveTranscript(formattedTranscript, date: extractDate(from: file.lastPathComponent))
        
        return formattedTranscript
    }
    
    private func deleteAndVerify(file: URL) -> Bool {
        do {
            try fileManager.removeItem(at: file)
            if !fileManager.fileExists(atPath: file.path) {
                print("Successfully deleted: \(file.lastPathComponent)")
                return true
            }
        } catch {
            print("Error deleting file: \(error)")
        }
        return false
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
        // Example filename format: "2024-03-21_14-30-45_to_14-35-20.wav"
        // We only want "2024-03-21"
        let components = filename.components(separatedBy: "_")
        if components.count >= 1 {
            // Take first component (year-month-day) and join them
            return components[0]
        }
        return "unknown_date"
    }
    
    private func saveTranscript(_ text: String, date: String) async throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }
        
        let transcriptsPath = documentsPath.appendingPathComponent("Transcripts")
        let transcriptURL = transcriptsPath.appendingPathComponent("\(date).txt")
        
        // If file exists, append to it instead of creating new
        if FileManager.default.fileExists(atPath: transcriptURL.path) {
            let existingContent = try String(contentsOf: transcriptURL, encoding: .utf8)
            let updatedContent = existingContent + "\n\n" + text
            try updatedContent.write(to: transcriptURL, atomically: true, encoding: .utf8)
        } else {
            try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
        }
    }
    
    private func extractTimeRange(from filename: String) -> (start: String, end: String) {
        // Example new filename format: "2024-03-21_14-30-45.wav"
        print("Processing file: \(filename)")
        
        let components = filename.components(separatedBy: "_")
        if components.count >= 2,
           let timeComponent = components.last?.replacingOccurrences(of: ".wav", with: "") {
            // Convert from "HH-mm-ss" to "HH:mm:ss"
            let formattedTime = timeComponent.replacingOccurrences(of: "-", with: ":")
            print("Extracted time: \(formattedTime)")
            return (formattedTime, "") // We only track start time now
        }
        
        print("Failed to parse time from filename: \(filename)")
        return ("unknown", "")
    }
    
    private func cleanupAllAudioStorage() async {
        let fileManager = FileManager.default
        let locations = [
            fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first,
            fileManager.temporaryDirectory
        ].compactMap { $0 }
        
        for location in locations {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: location,
                    includingPropertiesForKeys: nil,
                    options: [.skipsHiddenFiles]
                )
                
                for file in contents where file.pathExtension == "wav" {
                    try? fileManager.removeItem(at: file)
                    print("Cleaned up cached file at: \(file.path)")
                }
            } catch {
                print("Error cleaning cache directory \(location.path): \(error)")
            }
        }
        
        // Clear URLSession cache
        URLCache.shared.removeAllCachedResponses()
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

import Foundation

actor WhisperService {
    static let shared = WhisperService()
    private let apiKey: String
    
    private init() {
        // Load API key from configuration
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API key not found")
        }
        self.apiKey = key
    }
    
    func transcribeAudioFiles(in directory: URL) async throws -> String {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "wav" }
        
        var fullTranscript = ""
        
        for audioFile in contents.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let transcript = try await transcribeAudio(file: audioFile)
            let timeRange = extractTimeRange(from: audioFile.lastPathComponent)
            fullTranscript += "From \(timeRange.start) to \(timeRange.end):\n\(transcript)\n\n"
        }
        
        try await saveTranscript(fullTranscript)
        return fullTranscript
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
    
    private func saveTranscript(_ text: String) async throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw TranscriptionError.saveFailed
        }
        
        let transcriptsPath = documentsPath.appendingPathComponent("Transcripts")
        
        // Format date for filename: YYYY_MM_DD
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy_MM_dd"
        let dateString = dateFormatter.string(from: Date())
        
        let transcriptURL = transcriptsPath.appendingPathComponent("\(dateString).txt")
        
        // Always overwrite the file
        try text.write(to: transcriptURL, atomically: true, encoding: .utf8)
    }
    
    private func extractTimeRange(from filename: String) -> (start: String, end: String) {
        // Example filename format: "2024-03-21_14-30-45_to_14-35-20.wav"
        let components = filename.components(separatedBy: "_to_")
        if components.count == 2 {
            let startPart = components[0].components(separatedBy: "_").last ?? "unknown"
            let endPart = components[1].replacingOccurrences(of: ".wav", with: "")
            
            // Convert from "HH-mm-ss" to "HH:mm:ss"
            let formattedStart = startPart.replacingOccurrences(of: "-", with: ":")
            let formattedEnd = endPart.replacingOccurrences(of: "-", with: ":")
            
            return (formattedStart, formattedEnd)
        }
        return ("unknown", "unknown")
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

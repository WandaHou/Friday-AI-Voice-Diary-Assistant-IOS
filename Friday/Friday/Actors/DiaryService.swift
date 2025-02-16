import Foundation
import UIKit

actor DiaryService: DiaryServiceProtocol {
    static let shared = DiaryService()
    private let fileManager: FileManagerProtocol
    private let apiKey: String
    
    init(fileManager: FileManagerProtocol = FileManager.default) {
        self.fileManager = fileManager
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API key not found")
        }
        self.apiKey = key
    }
    
    // Add method to build system prompt from notes
    private func buildSystemPrompt(from notes: [Note]) -> String {
        let guidelines = notes.map { "- " + $0.content }.joined(separator: "\n")
        return """
        Please create a diary entry based on the following transcript.
        Follow these guidelines:
        \(guidelines)
        
        Transcript:
        """
    }
    
    func createDiary(from transcriptFile: URL, using notes: [Note]) async throws -> String {
        // Read transcript content
        let transcript = try String(contentsOf: transcriptFile, encoding: .utf8)
        
        // Create diary using GPT with custom prompt from notes
        let customPrompt = buildSystemPrompt(from: notes)
        let prompt = customPrompt + "\n\(transcript)"
        
        let diary = try await generateDiary(from: prompt)
        
        // Save diary
        try await saveDiary(diary, date: extractDateFromURL(transcriptFile))
        return diary
    }
    
    private func extractDateFromURL(_ url: URL) -> String {
        // Get filename without extension (e.g., "2025-01-02")
        return url.deletingPathExtension().lastPathComponent
    }
    
    private func generateDiary(from prompt: String) async throws -> String {
        // Adjust token thresholds for GPT-4 Turbo's larger context window
        let wordCount = Double(prompt.split(separator: " ").count)
        let estimatedTokens = Int(wordCount * 1.3)
        
        // Increased threshold to match GPT-4 Turbo's capacity
        if estimatedTokens > 100000 { // Leave room for system prompt and response
            return try await processLongTranscript(prompt)
        }
        
        return try await makeAPIRequest(with: prompt)
    }
    
    private func processLongTranscript(_ prompt: String) async throws -> String {
        // Split the transcript into chunks
        let chunks = splitTranscript(prompt)
        var combinedDiary = ""
        
        // Process each chunk
        for (index, chunk) in chunks.enumerated() {
            let chunkPrompt = """
            This is part \(index + 1) of \(chunks.count) of the transcript.
            Please process this part and maintain consistency with other parts.
            
            \(chunk)
            """
            
            let partialDiary = try await makeAPIRequest(with: chunkPrompt)
            combinedDiary += partialDiary + "\n"
        }
        
        // Final pass to ensure coherence
        let finalPrompt = """
        Please create a coherent and concise diary entry from these segments, maintaining the key points and flow:
        
        \(combinedDiary)
        """
        
        return try await makeAPIRequest(with: finalPrompt)
    }
    
    private func makeAPIRequest(with prompt: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": "You are an AI assistant that converts speech transcripts into diaries. Focus on presenting the content directly without diary formatting conventions."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.8,
            "max_tokens": 4096
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (responseData, response) = try await URLSession.shared.data(for: request)
        
//        // Print response for debugging
//        if let responseString = String(data: responseData, encoding: .utf8) {
//            print("API Response: \(responseString)")
//        }
        
        // Check HTTP status code
        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            let error = try? JSONDecoder().decode(ChatResponse.self, from: responseData)
            throw DiaryError.apiError(error?.error?.message ?? "API request failed with status \(httpResponse.statusCode)")
        }
        
        let chatResponse = try JSONDecoder().decode(ChatResponse.self, from: responseData)
        
        guard let firstChoice = chatResponse.choices?.first,
              !firstChoice.message.content.isEmpty else {
            throw DiaryError.invalidResponse
        }
        
        return firstChoice.message.content
    }
    
    private func splitTranscript(_ prompt: String) -> [String] {
        let maxChunkSize = 2000 // tokens
        var chunks: [String] = []
        let sentences = prompt.components(separatedBy: ". ")
        var currentChunk = ""
        
        for sentence in sentences {
            let potentialChunk = currentChunk + sentence + ". "
            let chunkTokens = Int(Double(potentialChunk.split(separator: " ").count) * 1.3)
            if chunkTokens > maxChunkSize {
                chunks.append(currentChunk)
                currentChunk = sentence + ". "
            } else {
                currentChunk = potentialChunk
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    private func saveDiary(_ text: String, date: String) async throws {
        guard let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DiaryError.saveFailed
        }
        
        let diariesPath = documentsPath.appendingPathComponent("Diaries")
        let diaryURL = diariesPath.appendingPathComponent("\(date).txt")
        try text.write(to: diaryURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Models
struct ChatResponse: Codable {
    let choices: [Choice]?
    let error: APIError?
    
    struct Choice: Codable {
        let message: Message
        let finishReason: String?
        
        enum CodingKeys: String, CodingKey {
            case message
            case finishReason = "finish_reason"
        }
    }
    
    struct Message: Codable {
        let content: String
    }
    
    struct APIError: Codable {
        let message: String
        let type: String
    }
}

enum DiaryError: Error {
    case saveFailed
    case apiError(String)
    case invalidResponse
}

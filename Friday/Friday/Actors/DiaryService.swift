import Foundation

actor DiaryService {
    static let shared = DiaryService()
    private let apiKey: String
    
    private init() {
        guard let key = Bundle.main.infoDictionary?["OPENAI_API_KEY"] as? String else {
            fatalError("OpenAI API key not found")
        }
        self.apiKey = key
    }
    
    func createDiary(from transcriptFile: URL) async throws -> String {
        // Read transcript content
        let transcript = try String(contentsOf: transcriptFile, encoding: .utf8)
        
        // Create diary using GPT with prompt from AIPrompts
        let prompt = AIPrompts.diaryCreation + "\n\(transcript)"
        
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
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are an AI assistant that converts speech transcripts into concise summaries. Focus on presenting the content directly without diary formatting conventions. Avoid greetings, signatures, or traditional diary structures."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.7
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (responseData, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(ChatResponse.self, from: responseData)
        
        return response.choices.first?.message.content ?? "No diary generated"
    }
    
    private func saveDiary(_ text: String, date: String) async throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            throw DiaryError.saveFailed
        }
        
        let diariesPath = documentsPath.appendingPathComponent("Diaries")
        let diaryURL = diariesPath.appendingPathComponent("\(date).txt")
        try text.write(to: diaryURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Models
struct ChatResponse: Codable {
    let choices: [Choice]
    
    struct Choice: Codable {
        let message: Message
    }
    
    struct Message: Codable {
        let content: String
    }
}

enum DiaryError: Error {
    case saveFailed
}

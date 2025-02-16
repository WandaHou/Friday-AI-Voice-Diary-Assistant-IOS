import Foundation

protocol DiaryServiceProtocol: Actor {
    func createDiary(from transcriptFile: URL, using notes: [Note]) async throws -> String
} 
import Foundation

protocol WhisperServiceProtocol: Actor {
    func transcribeAudioFiles(in directory: URL) async throws -> String
    func transcribeSingleFile(_ file: URL) async throws -> String
} 
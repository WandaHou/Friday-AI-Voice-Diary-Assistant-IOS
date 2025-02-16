import Foundation
import SwiftUI
import Combine
import UIKit

@MainActor
class FridayViewModel: ObservableObject {
    let audioService: AudioRecorderProtocol
    private let transcriptionService: WhisperServiceProtocol
    private let diaryService: DiaryServiceProtocol
    
    @Published var isTranscribing = false
    @Published var isGeneratingDiary = false
    @Published var voiceDetectorActive = false
    
    init(
        audioService: AudioRecorderProtocol = AudioRecorder.shared,
        transcriptionService: WhisperServiceProtocol = WhisperService.shared,
        diaryService: DiaryServiceProtocol = DiaryService.shared
    ) {
        self.audioService = audioService
        self.transcriptionService = transcriptionService
        self.diaryService = diaryService
    }
    
    func toggleVoiceDetector() async {
        voiceDetectorActive.toggle()
        if voiceDetectorActive {
            try? await audioService.startListening()
        } else {
            await audioService.stopListening()
        }
    }
    
    func transcribeRecordings() async throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let audioPath = documentsPath.appendingPathComponent("AudioRecords")
        isTranscribing = true
        defer { isTranscribing = false }
        
        _ = try await transcriptionService.transcribeAudioFiles(in: audioPath)
        
        URLCache.shared.removeAllCachedResponses() // clean cache files
    }
    
    func generateDiary() async throws {
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return
        }
        
        let transcriptsPath = documentsPath.appendingPathComponent("Transcripts")
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        let dateString = dateFormatter.string(from: Date())
        let transcriptURL = transcriptsPath.appendingPathComponent("\(dateString).txt")
        
        isGeneratingDiary = true
        defer { isGeneratingDiary = false }
        
        // Load saved notes for custom prompt
        if let data = UserDefaults.standard.data(forKey: "SystemPromptNotes"),
           let savedNotes = try? JSONDecoder().decode([Note].self, from: data) {
            _ = try await diaryService.createDiary(from: transcriptURL, using: savedNotes)
        }
    }
} 

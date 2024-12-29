import Foundation

// Base protocol for all view models
protocol ViewModel {
    func onViewDidLoad()
}

protocol TranscriptListViewModel: ViewModel {
    var recordings: [(audio: URL, transcript: URL?)] { get }
    var onRecordingsUpdated: (() -> Void)? { get set }
    
    func loadTranscripts() async
    func getDisplayTitle(for recording: URL) -> String
    func getTranscript(for recording: URL) async -> String?
}

// Implementation
class TranscriptListViewModelImpl: TranscriptListViewModel {
    private let storageManager: AudioStorageManaging
    private(set) var recordings: [(audio: URL, transcript: URL?)] = []
    var onRecordingsUpdated: (() -> Void)?
    
    init(storageManager: AudioStorageManaging) {
        self.storageManager = storageManager
    }
    
    func onViewDidLoad() {
        Task { await loadTranscripts() }
    }
    
    func loadTranscripts() async {
        do {
            recordings = try await storageManager.getAllRecordings()
            // Sort by date (newest first)
            recordings.sort { first, second in
                first.audio.lastPathComponent > second.audio.lastPathComponent
            }
            await MainActor.run {
                onRecordingsUpdated?()
            }
        } catch {
            print("Failed to load recordings: \(error)")
        }
    }
    
    func getDisplayTitle(for recording: URL) -> String {
        let fileName = recording.deletingPathExtension().lastPathComponent
        return formatDate(from: fileName)
    }
    
    func getTranscript(for recording: URL) async -> String? {
        let fileName = recording.deletingPathExtension().lastPathComponent
        return try? await storageManager.getTranscript(for: fileName)
    }
    
    private func formatDate(from fileName: String) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "MM-dd-yy HH:mm:ss"
        
        if let date = dateFormatter.date(from: fileName) {
            dateFormatter.dateStyle = .medium
            dateFormatter.timeStyle = .short
            return dateFormatter.string(from: date)
        }
        return fileName
    }
} 

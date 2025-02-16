import Foundation
import AVFoundation

protocol AudioRecorderProtocol: Actor {
    var currentAudioLevel: Float? { get async }
    var threshold: Float { get }
    
    func startListening() async throws
    func stopListening()
} 
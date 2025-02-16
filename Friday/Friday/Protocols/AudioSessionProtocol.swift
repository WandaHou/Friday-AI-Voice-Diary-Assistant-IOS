import Foundation
import AVFoundation

protocol AudioSessionProtocol: AnyObject {
    func activate() async throws
    func deactivate()
} 
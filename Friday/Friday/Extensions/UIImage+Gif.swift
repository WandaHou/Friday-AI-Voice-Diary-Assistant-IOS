import UIKit
import ImageIO

extension UIImage {
    static func gifImageWithData(_ data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        var images = [UIImage]()
        var duration: TimeInterval = 0
        
        for i in 0..<count {
            if let cgImage = CGImageSourceCreateImageAtIndex(source, i, nil) {
                if let properties = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [String: Any],
                   let gifInfo = properties[kCGImagePropertyGIFDictionary as String] as? [String: Any] {
                    if let delayTime = gifInfo[kCGImagePropertyGIFDelayTime as String] as? Double {
                        duration += delayTime
                    }
                }
                images.append(UIImage(cgImage: cgImage))
            }
        }
        
        if images.count == 1 {
            return images.first
        } else {
            return UIImage.animatedImage(with: images, duration: duration)
        }
    }
} 
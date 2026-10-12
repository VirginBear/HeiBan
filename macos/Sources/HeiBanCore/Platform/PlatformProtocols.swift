import Foundation
import CoreGraphics
import ImageIO

public protocol PlatformDialogService: AnyObject {
    func runSavePanel(defaultName: String, allowedExtensions: [String], completion: @escaping (URL?) -> Void)
    func runOpenPanel(allowedExtensions: [String], allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void)
}

public extension PlatformDialogService {
    func runSavePanel(defaultName: String, completion: @escaping (URL?) -> Void) {
        runSavePanel(defaultName: defaultName, allowedExtensions: ["blackboard.json", "json"], completion: completion)
    }
    func runOpenPanel(completion: @escaping (URL?) -> Void) {
        runOpenPanel(allowedExtensions: ["blackboard.json", "json", "heiban"], allowsMultiple: false) { urls in
            completion(urls?.first)
        }
    }
}

public protocol PlatformPasteboardService: AnyObject {
    func copyString(_ text: String)
    func pasteString() -> String?
    func pasteImageData() -> (data: Data, width: Double, height: Double)?
    func readImage(completion: @escaping ((data: Data, width: Double, height: Double)?) -> Void)
}

public extension PlatformPasteboardService {
    func readImage(completion: @escaping ((data: Data, width: Double, height: Double)?) -> Void) {
        completion(pasteImageData())
    }
}

public protocol PlatformImageDecoderService: AnyObject {
    func getImageDimensions(from data: Data) -> (width: Double, height: Double)?
    func convertImageToPNGData(from data: Data) -> Data?
}

public enum ScreenCaptureResult {
    case image(Data)
    case cancelled
    case failed(String)
}

/// Native UI and capture permissions belong to the platform, not the board model.
public protocol PlatformScreenCaptureService: AnyObject {
    func capture(mode: ScreenCaptureMode, completion: @escaping (ScreenCaptureResult) -> Void)
}

public struct CoreImageDecoder {
    public static func getDimensions(from data: Data) -> (width: Double, height: Double)? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        guard let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else { return nil }
        guard let w = properties[kCGImagePropertyPixelWidth] as? Double,
              let h = properties[kCGImagePropertyPixelHeight] as? Double else { return nil }
        return (w, h)
    }
}

import Foundation
import AppKit
import UniformTypeIdentifiers
import HeiBanCore

public final class MacPlatformDialogService: PlatformDialogService {
    public init() {}

    public func runSavePanel(defaultName: String, allowedExtensions: [String], completion: @escaping (URL?) -> Void) {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = defaultName
        let types = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }
        if panel.runModal() == .OK {
            completion(panel.url)
        } else {
            completion(nil)
        }
    }

    public func runOpenPanel(allowedExtensions: [String], allowsMultiple: Bool, completion: @escaping ([URL]?) -> Void) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = allowsMultiple
        let types = allowedExtensions.compactMap { UTType(filenameExtension: $0) }
        if !types.isEmpty {
            panel.allowedContentTypes = types
        }
        if panel.runModal() == .OK {
            completion(panel.urls)
        } else {
            completion(nil)
        }
    }
}

public final class MacPlatformPasteboardService: PlatformPasteboardService {
    private let pasteboard: NSPasteboard

    /// 可注入專用貼上板，原生影像檢查不覆寫使用者剪貼簿。
    public init(pasteboard: NSPasteboard = .general) { self.pasteboard = pasteboard }

    public func copyString(_ text: String) {
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    public func pasteString() -> String? {
        return pasteboard.string(forType: .string)
    }

    public static var containsImage: Bool {
        let pb = NSPasteboard.general
        return pb.canReadObject(forClasses: [NSImage.self, NSURL.self], options: nil)
    }

    public func pasteImageData() -> (data: Data, width: Double, height: Double)? {
        let pb = pasteboard
        if let image = NSImage(pasteboard: pb), let result = Self.png(image) { return result }
        if let urls = pb.readObjects(forClasses: [NSURL.self], options: [.urlReadingFileURLsOnly: true]) as? [URL],
           let url = urls.first, let image = NSImage(contentsOf: url) { return Self.png(image) }
        return nil
    }

    public func readImage(completion: @escaping ((data: Data, width: Double, height: Double)?) -> Void) {
        if let image = pasteImageData() { completion(image); return }
        guard let url = NSURL(from: pasteboard) as URL?,
              ["https", "http"].contains(url.scheme?.lowercased() ?? "") else { completion(nil); return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        URLSession.shared.dataTask(with: request) { data, response, _ in
            // 僅接收影像，拒絕網頁／失敗回應；原 URL 不寫進作品或紀錄。
            let valid = (response as? HTTPURLResponse).map { (200...299).contains($0.statusCode) } ?? false
            DispatchQueue.main.async {
                guard valid, let data, data.count <= 32 * 1024 * 1024,
                      let image = NSImage(data: data), let result = Self.png(image) else { completion(nil); return }
                completion(result)
            }
        }.resume()
    }

    private static func png(_ image: NSImage) -> (data: Data, width: Double, height: Double)? {
        guard let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff),
              let data = bitmap.representation(using: .png, properties: [:]) else { return nil }
        return (data, Double(bitmap.pixelsWide), Double(bitmap.pixelsHigh))
    }

}

public final class MacPlatformImageDecoderService: PlatformImageDecoderService {
    public init() {}

    public func getImageDimensions(from data: Data) -> (width: Double, height: Double)? {
        if let img = NSImage(data: data), img.isValid {
            return (Double(img.size.width), Double(img.size.height))
        }
        return CoreImageDecoder.getDimensions(from: data)
    }

    public func convertImageToPNGData(from data: Data) -> Data? {
        guard let img = NSImage(data: data),
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return nil
        }
        return png
    }
}

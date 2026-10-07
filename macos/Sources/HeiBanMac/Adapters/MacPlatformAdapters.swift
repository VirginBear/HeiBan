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
    public init() {}

    public func copyString(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    public func pasteString() -> String? {
        return NSPasteboard.general.string(forType: .string)
    }

    public func pasteImageData() -> (data: Data, width: Double, height: Double)? {
        let pb = NSPasteboard.general
        guard let image = NSImage(pasteboard: pb) else { return nil }
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:]) else {
            return nil
        }
        return (data: pngData, width: Double(image.size.width), height: Double(image.size.height))
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

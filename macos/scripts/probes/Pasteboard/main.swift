import AppKit
import HeiBanCore
import Foundation
let pb = NSPasteboard(name: .init("HeiBan.image-verification.\(UUID().uuidString)"))
defer { pb.releaseGlobally() }
let service = MacPlatformPasteboardService(pasteboard: pb)
let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 24, pixelsHigh: 16, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
bitmap.size = NSSize(width: 12, height: 8)
let png = bitmap.representation(using: .png, properties: [:])!
let tiff = bitmap.representation(using: .tiff, properties: [:])!
let imageURL = URL(fileURLWithPath: "/tmp/HeiBan-clipboard-fixture.png")
try png.write(to: imageURL)
defer { try? FileManager.default.removeItem(at: imageURL) }
var passed = 0
for (kind, data) in [(NSPasteboard.PasteboardType.png, png), (.tiff, tiff)] {
 pb.clearContents();pb.setData(data, forType: kind)
 guard let image = service.pasteImageData() else { fatalError("Cannot read \(kind)") }
 precondition(image.width == 24 && image.height == 16, "Must use pixel dimensions")
 let engine = BoardEngine(restoreSession: false, persistenceEnabled: false)
 engine.showingHome = false;engine.canvasSize = CGSize(width:800,height:600);engine.pasteboardService = service
 engine.pasteClipboard();precondition(engine.objects.count == 1 && engine.objects[0].type == "image")
 engine.undo();precondition(engine.objects.isEmpty);passed += 3
}
pb.clearContents();precondition(pb.writeObjects([imageURL as NSURL]));precondition(service.pasteImageData()?.width == 24);passed += 2
pb.clearContents();pb.setString("plain text", forType: .string);precondition(service.pasteImageData() == nil);passed += 1
print("Mac AppKit pasteboard: \(passed)/\(passed) assertions passed (PNG, TIFF, file URL, pixel dimensions, canvas insertion, Undo, text rejection). General clipboard untouched.")

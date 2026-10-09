// Package the approved wordmark at macOS icon sizes, preserving its aspect ratio.
import AppKit
import Foundation

let root = URL(fileURLWithPath: CommandLine.arguments[1])
let logo = NSImage(contentsOf: root.appendingPathComponent("Sources/HeiBanMac/Resources/HeiBanLogo.png"))!
let iconset = root.appendingPathComponent("assets/branding/HeiBan.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func render(_ pixels: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: pixels, height: pixels)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let side = CGFloat(pixels)
    NSColor.clear.setFill(); NSRect(x: 0, y: 0, width: side, height: side).fill()
    let tile = NSRect(x: side * 0.06, y: side * 0.06, width: side * 0.88, height: side * 0.88)
    NSColor(calibratedRed: 0.975, green: 0.975, blue: 0.95, alpha: 1).setFill()
    NSBezierPath(roundedRect: tile, xRadius: side * 0.19, yRadius: side * 0.19).fill()
    let width = side * 0.76
    let height = width * logo.size.height / logo.size.width
    logo.draw(in: NSRect(x: (side - width) / 2, y: (side - height) / 2, width: width, height: height),
              from: .zero, operation: .sourceOver, fraction: 1)
    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])!
}
for points in [16, 32, 128, 256, 512] {
    try render(points).write(to: iconset.appendingPathComponent("icon_\(points)x\(points).png"))
    try render(points * 2).write(to: iconset.appendingPathComponent("icon_\(points)x\(points)@2x.png"))
}
try render(1024).write(to: root.appendingPathComponent("Sources/HeiBanMac/Resources/HeiBanAppIcon.png"))

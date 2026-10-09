import AppKit
import ScreenCaptureKit
import CoreImage
import CoreMedia
import HeiBanCore

/// One-shot capture. A system picker grant is sufficient even when a development
/// build's previous Screen Recording grant no longer matches its signature.
final class MacScreenCaptureService: NSObject, PlatformScreenCaptureService, SCContentSharingPickerObserver, SCStreamDelegate {
    private var completion: ((ScreenCaptureResult) -> Void)?
    private var mode: ScreenCaptureMode = .region
    private var capturing = false
    private var selectionWindow: NSWindow?
    private weak var returnWindow: NSWindow?
    private var captureStream: SCStream?
    private var frameOutput: SingleScreenshotOutput?
    private var frameTimeout: DispatchWorkItem?
    private let frameQueue = DispatchQueue(label: "com.bear.HeiBan.screenshot", qos: .userInitiated)

    func capture(mode: ScreenCaptureMode, completion: @escaping (ScreenCaptureResult) -> Void) {
        precondition(Thread.isMainThread)
        guard self.completion == nil else { return }
        self.completion = completion
        self.mode = mode
        returnWindow = NSApp.keyWindow
        if CGPreflightScreenCaptureAccess() {
            captureAuthorizedDisplay()
        } else {
            presentPicker()
        }
    }

    func cancel() {
        guard completion != nil else { return }
        finish(.cancelled)
    }

    private func presentPicker() {
        capturing = false
        let picker = SCContentSharingPicker.shared
        var configuration = SCContentSharingPickerConfiguration()
        configuration.allowedPickerModes = [.singleDisplay]
        configuration.allowsChangingSelectedContent = false
        picker.defaultConfiguration = configuration
        picker.add(self)
        picker.isActive = true
        picker.present(using: .display)
    }

    private func captureAuthorizedDisplay() {
        let mouseScreen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        let displayID = (mouseScreen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value
        Task { @MainActor in
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
                let display: SCDisplay?
                if case .display(let index) = mode {
                    // Match screencapture's 1-based ordering: main screen, then remaining screens.
                    let screens = NSScreen.screens
                    guard index > 0, index <= screens.count,
                          let id = (screens[index - 1].deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value else {
                        finish(.failed("找不到指定的顯示器"))
                        return
                    }
                    display = content.displays.first { $0.displayID == id }
                } else {
                    display = content.displays.first { $0.displayID == displayID }
                }
                guard let display else {
                    presentPicker()
                    return
                }
                let filter = SCContentFilter(display: display, excludingWindows: [])
                takeImage(filter: filter, screen: screen(for: display.displayID), fromPicker: false)
            } catch {
                // Do not block on a stale preflight permission flag. Let macOS authorize
                // the precise content chosen by the user instead.
                presentPicker()
            }
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didCancelFor stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.capturing else { return }
            self.finish(.cancelled)
        }
    }

    func contentSharingPicker(_ picker: SCContentSharingPicker, didUpdateWith filter: SCContentFilter, for stream: SCStream?) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.completion != nil, !self.capturing else { return }
            var screen: NSScreen?
            if #available(macOS 15.2, *) {
                screen = filter.includedDisplays.first.flatMap { self.screen(for: $0.displayID) }
            }
            self.takeImage(filter: filter, screen: screen, fromPicker: true)
        }
    }

    func contentSharingPickerStartDidFailWithError(_ error: Error) {
        DispatchQueue.main.async { [weak self] in self?.reportFailure(error) }
    }

    private func screen(for displayID: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }
    }

    private func takeImage(filter: SCContentFilter, screen: NSScreen?, fromPicker: Bool) {
        guard completion != nil, !capturing else { return }
        capturing = true
        let config = SCStreamConfiguration()
        let scale = max(1, Double(filter.pointPixelScale))
        config.width = max(1, Int((filter.contentRect.width * scale).rounded()))
        config.height = max(1, Int((filter.contentRect.height * scale).rounded()))
        config.showsCursor = false
        if fromPicker {
            // SCScreenshotManager can still require broad TCC authorization after
            // choosing content. A picker-authorized stream carries that specific grant.
            // Give the system's picker dismissal animation time to finish so its
            // selection controls are not frozen into the screenshot.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self, self.completion != nil else { return }
                self.capturePickerFrame(filter: filter, config: config, screen: screen)
            }
            return
        }
        Task { @MainActor in
            do {
                let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: config)
                guard completion != nil else { return }
                if mode == .region {
                    showRegionSelection(image: image, screen: screen)
                } else {
                    finishImage(image)
                }
            } catch {
                if fromPicker { reportFailure(error) }
                else { presentPicker() }
            }
        }
    }

    private func capturePickerFrame(filter: SCContentFilter, config: SCStreamConfiguration, screen: NSScreen?) {
        config.capturesAudio = false
        config.minimumFrameInterval = CMTime(value: 1, timescale: 30)
        let stream = SCStream(filter: filter, configuration: config, delegate: self)
        let output = SingleScreenshotOutput()
        captureStream = stream
        frameOutput = output
        output.onImage = { [weak self, weak stream] image in
            DispatchQueue.main.async {
                guard let self, let stream, self.captureStream === stream, self.completion != nil else { return }
                self.frameTimeout?.cancel()
                self.frameTimeout = nil
                self.captureStream = nil
                Task { @MainActor in
                    try? await stream.stopCapture()
                    self.frameOutput = nil
                    guard self.completion != nil else { return }
                    if self.mode == .region { self.showRegionSelection(image: image, screen: screen) }
                    else { self.finishImage(image) }
                }
            }
        }
        do {
            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: frameQueue)
        } catch {
            reportFailure(error)
            return
        }
        let timeout = DispatchWorkItem { [weak self, weak stream] in
            guard let self, let stream, self.captureStream === stream else { return }
            self.reportFailure(NSError(domain: "HeiBan.ScreenCapture", code: 1, userInfo: [NSLocalizedDescriptionKey: "等待截圖畫面逾時，請重新選擇螢幕"]))
        }
        frameTimeout = timeout
        DispatchQueue.main.asyncAfter(deadline: .now() + 15, execute: timeout)
        Task { @MainActor in
            do { try await stream.startCapture() }
            catch {
                guard captureStream === stream else { return }
                reportFailure(error)
            }
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.captureStream === stream else { return }
            self.reportFailure(error)
        }
    }

    private func showRegionSelection(image: CGImage, screen: NSScreen?) {
        guard let target = screen ?? returnWindow?.screen ?? NSScreen.main else {
            finish(.failed("找不到可用的螢幕"))
            return
        }
        let window = CaptureSelectionWindow(contentRect: target.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.setFrame(target.frame, display: false)
        window.level = .popUpMenu
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        let view = CaptureRegionView(image: image)
        view.onFinish = { [weak self] cropped in
            guard let self else { return }
            if let cropped { self.finishImage(cropped) }
            else { self.finish(.cancelled) }
        }
        window.contentView = view
        selectionWindow = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(view)
    }

    private func finishImage(_ image: CGImage) {
        guard let data = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            finish(.failed("無法編碼截圖"))
            return
        }
        finish(.image(data))
    }

    private func reportFailure(_ error: Error) {
        guard completion != nil else { return }
        let nsError = error as NSError
        let detail = "\(nsError.localizedDescription)（\(nsError.domain) / \(nsError.code)）"
        let alert = NSAlert()
        alert.messageText = "無法擷取螢幕"
        alert.informativeText = "系統未能完成這次截圖。若系統選取也失敗，請檢查「隱私權與安全性 → 螢幕與系統音訊錄製」中的黑板是否為目前開啟的版本，重新開啟黑板後再試。\n\n\(detail)"
        alert.addButton(withTitle: "關閉")
        alert.addButton(withTitle: "開啟權限設定")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertSecondButtonReturn,
           let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture") {
            NSWorkspace.shared.open(url)
        }
        finish(.failed(detail))
    }

    private func finish(_ result: ScreenCaptureResult) {
        let callback = completion
        completion = nil
        frameTimeout?.cancel()
        frameTimeout = nil
        if let stream = captureStream {
            captureStream = nil
            Task { try? await stream.stopCapture() }
        }
        frameOutput = nil
        selectionWindow?.orderOut(nil)
        selectionWindow?.close()
        selectionWindow = nil
        let picker = SCContentSharingPicker.shared
        picker.remove(self)
        picker.isActive = false
        capturing = false
        NSApp.activate(ignoringOtherApps: true)
        returnWindow?.makeKeyAndOrderFront(nil)
        returnWindow = nil
        callback?(result)
    }
}

/// Used on a serial sample queue; only the first complete frame is converted.
private final class SingleScreenshotOutput: NSObject, SCStreamOutput {
    var onImage: ((CGImage) -> Void)?
    private var delivered = false
    private let context = CIContext()

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, !delivered, sampleBuffer.isValid,
              let attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, createIfNecessary: false) as? [[SCStreamFrameInfo: Any]],
              let status = attachments.first?[.status] as? Int,
              status == SCFrameStatus.complete.rawValue,
              let buffer = sampleBuffer.imageBuffer else { return }
        let image = CIImage(cvPixelBuffer: buffer)
        guard let snapshot = context.createCGImage(image, from: image.extent) else { return }
        delivered = true
        onImage?(snapshot)
    }
}

private final class CaptureSelectionWindow: NSWindow {
    override var canBecomeKey: Bool { true }
}

/// Select on a frozen capture, so no other screen pixels are read while dragging.
private final class CaptureRegionView: NSView {
    let image: CGImage
    var onFinish: ((CGImage?) -> Void)?
    private var start: CGPoint?
    private var selection: CGRect = .zero
    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    init(image: CGImage) {
        self.image = image
        super.init(frame: .zero)
    }
    required init?(coder: NSCoder) { nil }

    override func resetCursorRects() { addCursorRect(bounds, cursor: .crosshair) }

    override func draw(_ dirtyRect: NSRect) {
        NSImage(cgImage: image, size: bounds.size).draw(in: bounds, from: .zero, operation: .copy, fraction: 1, respectFlipped: true, hints: nil)
        let shade = NSBezierPath(rect: bounds)
        if !selection.isEmpty { shade.appendRect(selection) }
        shade.windingRule = .evenOdd
        NSColor.black.withAlphaComponent(0.35).setFill()
        shade.fill()
        if !selection.isEmpty {
            NSColor.white.setStroke()
            let border = NSBezierPath(rect: selection)
            border.lineWidth = 1.5
            border.stroke()
        }
        let text = "拖曳框選截圖區域 · Esc 或右鍵取消"
        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 15, weight: .medium), .foregroundColor: NSColor.white]
        let size = (text as NSString).size(withAttributes: attributes)
        let badge = CGRect(x: (bounds.width - size.width) / 2 - 16, y: 28, width: size.width + 32, height: size.height + 20)
        NSColor.black.withAlphaComponent(0.75).setFill()
        NSBezierPath(roundedRect: badge, xRadius: 10, yRadius: 10).fill()
        (text as NSString).draw(at: CGPoint(x: badge.minX + 16, y: badge.minY + 10), withAttributes: attributes)
    }

    override func mouseDown(with event: NSEvent) {
        start = convert(event.locationInWindow, from: nil)
        selection = .zero
        needsDisplay = true
    }
    override func mouseDragged(with event: NSEvent) { updateSelection(event) }
    private func updateSelection(_ event: NSEvent) {
        guard let start else { return }
        let end = convert(event.locationInWindow, from: nil)
        selection = CGRect(x: min(start.x, end.x), y: min(start.y, end.y), width: abs(end.x - start.x), height: abs(end.y - start.y)).intersection(bounds)
        needsDisplay = true
    }
    override func mouseUp(with event: NSEvent) {
        updateSelection(event)
        start = nil
        guard selection.width >= 3, selection.height >= 3, bounds.width > 0, bounds.height > 0 else { return }
        let sx = CGFloat(image.width) / bounds.width
        let sy = CGFloat(image.height) / bounds.height
        let rect = CGRect(x: selection.minX * sx, y: selection.minY * sy, width: selection.width * sx, height: selection.height * sy).integral.intersection(CGRect(x: 0, y: 0, width: image.width, height: image.height))
        guard let cropped = image.cropping(to: rect) else { return }
        finish(cropped)
    }
    override func rightMouseDown(with event: NSEvent) { finish(nil) }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { finish(nil) }
        else { super.keyDown(with: event) }
    }
    private func finish(_ image: CGImage?) {
        let callback = onFinish
        onFinish = nil
        callback?(image)
    }
}

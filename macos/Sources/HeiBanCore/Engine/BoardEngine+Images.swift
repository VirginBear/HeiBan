import CoreGraphics
import Foundation
import UniformTypeIdentifiers

/// 圖片來源、裁切與截圖結果置入。平台服務管理權限，核心只建立可保存的圖片物件。
extension BoardEngine {
    // MARK: - Image Assets, Non-Destructive 8-Way Crop & Multi-Screen Capture (W20, A18, A19)
    public func importImage(data: Data, originalSize: CGSize, fileName: String? = nil) -> BoardObject {
        let centerScreen = Point(x: canvasSize.width / 2, y: canvasSize.height / 2)
        let center = VectorMath.screenToWorld(centerScreen, viewport: viewport)
        let object = embeddedImage(data: data, size: originalSize, filename: fileName, center: center)
        addObject(object)
        selectedIds = [object.id]
        return object
    }

    public func isImageCropped(id: String) -> Bool {
        guard let obj = objects.first(where: { $0.id == id }) else { return false }
        return obj.cropWidth != nil && obj.cropHeight != nil
    }

    public func cropImage(id: String, cropRect: CGRect) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.cropX = cropRect.origin.x
        updated.cropY = cropRect.origin.y
        updated.cropWidth = cropRect.width
        updated.cropHeight = cropRect.height

        if let origW = prev.originalWidth, origW > 0 {
            let scale = prev.width / origW
            updated.width = cropRect.width * scale
            updated.height = cropRect.height * scale
        }

        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    public func resetImageCrop(id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }) else { return }
        let prev = objects[index]
        var updated = prev
        updated.cropX = nil
        updated.cropY = nil
        updated.cropWidth = nil
        updated.cropHeight = nil

        if let origW = prev.originalWidth, let origH = prev.originalHeight, origW > 0, origH > 0 {
            let maxDisplayW = 420.0
            let scale = min(1.0, maxDisplayW / origW)
            updated.width = origW * scale
            updated.height = origH * scale
        }

        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [prev], after: [updated]))
        scheduleAutosave()
    }

    // 舊命令列截圖的相容入口，僅既有檢查使用；正式流程由 PlatformScreenCaptureService 負責。
    // 不可重新把 Process／screencapture 權限處理接回畫布引擎。
    public func makeScreenCaptureArguments(mode: ScreenCaptureMode, outputPath: String) -> [String] {
        switch mode {
        case .region:
            return ["-i", outputPath]
        case .display(let idx):
            return ["-D", "\(idx)", outputPath]
        }
    }

    public func handleScreenCaptureResult(exitCode: Int32, tempFileURL: URL?) {
        guard exitCode == 0, let tempFileURL, FileManager.default.fileExists(atPath: tempFileURL.path) else {
            showTemporaryStatus("已取消截圖")
            if let tempFileURL {
                try? FileManager.default.removeItem(at: tempFileURL)
            }
            return
        }

        guard let data = try? Data(contentsOf: tempFileURL),
            let (pixelWidth, pixelHeight) = imageDecoderService?.getImageDimensions(from: data)
                ?? CoreImageDecoder.getDimensions(from: data)
        else {
            showTemporaryStatus("載入截圖失敗")
            try? FileManager.default.removeItem(at: tempFileURL)
            return
        }

        _ = importImage(data: data, originalSize: CGSize(width: pixelWidth, height: pixelHeight))
        try? FileManager.default.removeItem(at: tempFileURL)
        showTemporaryStatus("已將螢幕截圖置入黑板！")
    }

    public func computeRetinaLogicalSize(pixelWidth: Double, pixelHeight: Double, backingScale: Double)
        -> CGSize
    {
        let scale = max(1.0, backingScale)
        return CGSize(width: pixelWidth / scale, height: pixelHeight / scale)
    }

    public func captureScreen(mode: ScreenCaptureMode = .region) {
        guard !screenCaptureInProgress else { return }
        guard let screenCaptureService else {
            showTemporaryStatus("截圖服務尚未就緒")
            return
        }
        let destinationBoard = board.id
        let destinationPage = activePageId
        screenCaptureInProgress = true
        showTemporaryStatus("請選擇螢幕並框選截圖區域，Esc 可取消")
        screenCaptureService.capture(mode: mode) { [weak self] result in
            guard let self else { return }
            self.screenCaptureInProgress = false
            switch result {
            case .cancelled:
                self.showTemporaryStatus("已取消截圖")
            case .failed(let message):
                self.showTemporaryStatus("截圖失敗：\(message)")
            case .image(let data):
                guard self.board.id == destinationBoard, self.activePageId == destinationPage,
                    !self.showingHome
                else {
                    self.showTemporaryStatus("作品已切換，未置入截圖")
                    return
                }
                guard let (width, height) = CoreImageDecoder.getDimensions(from: data) else {
                    self.showTemporaryStatus("無法讀取截圖圖片")
                    return
                }
                _ = self.importImage(data: data, originalSize: CGSize(width: width, height: height))
                self.showTemporaryStatus("已將螢幕截圖置入黑板")
            }
        }
    }

    public func captureScreenAndPaste() {
        captureScreen(mode: .region)
    }

    public func pasteImageFromClipboard() {
        guard let (data, width, height) = pasteboardService?.pasteImageData() else {
            showTemporaryStatus("剪貼簿無可用圖片")
            return
        }

        _ = importImage(data: data, originalSize: CGSize(width: width, height: height))
        showTemporaryStatus("已將剪貼簿圖片置入黑板！")
    }

    /// Import local image files as editable image objects on the current board.
    /// The original bytes are embedded in the board document so saving the board
    /// preserves the imported image without a separate asset folder.
    public func importImageFromFilePrompt() {
        guard let dialogService = dialogService else {
            showTemporaryStatus("平台對話框服務未就緒")
            return
        }

        dialogService.runOpenPanel(
            allowedExtensions: ["png", "jpg", "jpeg", "gif", "webp", "bmp", "tiff"], allowsMultiple: true
        ) { [weak self] urls in
            guard let self = self, let urls = urls, !urls.isEmpty else { return }

            let centerScreen = Point(
                x: Double(self.canvasSize.width / 2), y: Double(self.canvasSize.height / 2))
            let worldCenter = VectorMath.screenToWorld(centerScreen, viewport: self.viewport)
            var imported: [BoardObject] = []
            var failures: [String] = []

            for (index, url) in urls.enumerated() {
                do {
                    let data = try Data(contentsOf: url)
                    guard
                        let (pixelWidth, pixelHeight) = self.imageDecoderService?.getImageDimensions(
                            from: data) ?? CoreImageDecoder.getDimensions(from: data),
                        pixelWidth > 0, pixelHeight > 0
                    else {
                        failures.append(url.lastPathComponent)
                        continue
                    }

                    let offset = Double(index) * 28
                    let object = self.embeddedImage(
                        data: data,
                        size: CGSize(width: pixelWidth, height: pixelHeight),
                        filename: url.lastPathComponent,
                        center: Point(x: worldCenter.x + offset, y: worldCenter.y + offset),
                        zOffset: imported.count,
                        initializeCrop: true
                    )
                    imported.append(object)
                } catch {
                    failures.append(url.lastPathComponent)
                }
            }

            guard !imported.isEmpty else {
                self.showTemporaryStatus(
                    failures.isEmpty ? "沒有匯入圖片" : "無法讀取圖片：\(failures.joined(separator: "、"))")
                return
            }

            imported.forEach(self.addObject)
            self.selectedIds = Set(imported.map(\.id))
            // addObject 已排程保存；選取是工作階段狀態，不另寫一次。
            let suffix = failures.isEmpty ? "" : "；\(failures.count) 個檔案無法讀取"
            self.showTemporaryStatus("已匯入 \(imported.count) 張圖片，可直接選取、移動並隨白板儲存\(suffix)")
        }
    }

    public func insertDroppedImage(_ data: Data, filename: String, at screenPoint: Point) {
        guard
            let (pixelWidth, pixelHeight) = imageDecoderService?.getImageDimensions(from: data)
                ?? CoreImageDecoder.getDimensions(from: data),
            pixelWidth > 0, pixelHeight > 0
        else {
            showTemporaryStatus("無法讀取拖入的圖片")
            return
        }
        let object = embeddedImage(
            data: data,
            size: CGSize(width: pixelWidth, height: pixelHeight),
            filename: filename,
            center: VectorMath.screenToWorld(screenPoint, viewport: viewport)
        )
        addObject(object)
        selectedIds = [object.id]
        showTemporaryStatus("已將 \(filename) 放入畫布")
    }

    /// 三個置入入口共用尺寸、資料 URL 與圖層規則；原始像素和顯示尺寸不能混為一談。
    /// 原圖 bytes 內嵌文件，裁切只修改視窗範圍，沒有重編碼或破壞原圖。
    private func embeddedImage(
        data: Data, size: CGSize, filename: String?, center: Point,
        zOffset: Int = 0, initializeCrop: Bool = false
    ) -> BoardObject {
        let scale = min(1.0, 420.0 / max(1.0, size.width))
        let width = size.width * scale
        let height = size.height * scale
        let mime =
            filename.flatMap {
                UTType(filenameExtension: URL(fileURLWithPath: $0).pathExtension)?.preferredMIMEType
            } ?? "image/png"
        let url = "data:\(mime);base64,\(data.base64EncodedString())"
        return BoardObject(
            boardId: board.id, type: "image",
            x: center.x - width / 2, y: center.y - height / 2,
            width: width, height: height,
            zIndex: (objects.map(\.zIndex).max() ?? 0) + zOffset + 1,
            imageUrl: url, originalImageUrl: url,
            originalWidth: size.width, originalHeight: size.height,
            cropX: initializeCrop ? 0 : nil, cropY: initializeCrop ? 0 : nil,
            cropWidth: initializeCrop ? size.width : nil, cropHeight: initializeCrop ? size.height : nil,
            name: filename
        )
    }
}

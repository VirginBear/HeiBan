import CoreGraphics
import Foundation

/// 選取屬性的混合值與樣式修改；鎖定物件不修改，每次操作只提交一次歷史與保存排程。
extension BoardEngine {
    // MARK: - Selected Object Properties & Mixed Values (A07)
    public var selectedObjects: [BoardObject] {
        objects.filter { selectedIds.contains($0.id) }
    }

    public var selectedStrokeColor: PropertyValue<String> {
        mixedValue(selectedObjects.map(\.strokeColor))
    }

    public var selectedFillColor: PropertyValue<String> {
        mixedValue(selectedObjects.map(\.fillColor))
    }

    public var selectedStrokeWidth: PropertyValue<Double> {
        mixedValue(selectedObjects.map(\.strokeWidth))
    }

    public var selectedOpacity: PropertyValue<Double> {
        mixedValue(selectedObjects.map(\.opacity))
    }

    public var selectedLineStyle: PropertyValue<String> {
        mixedValue(selectedObjects.map { $0.lineStyle ?? "solid" })
    }

    public var selectedRotation: PropertyValue<Double> {
        mixedValue(selectedObjects.map(\.rotation))
    }

    public var selectedLineExtension: PropertyValue<LineExtension> {
        mixedValue(
            selectedObjects.filter { $0.type == "line" || $0.type == "arrow" }.map {
                $0.extensionMode ?? .none
            })
    }

    public var selectedArrowHeadLength: PropertyValue<Double> {
        mixedValue(selectedObjects.filter { $0.type == "arrow" }.map { $0.arrowHeadLength ?? 16 })
    }

    public var selectedArrowHeadWidth: PropertyValue<Double> {
        mixedValue(selectedObjects.filter { $0.type == "arrow" }.map { $0.arrowHeadWidth ?? 10 })
    }

    public var selectedStickyStyle: PropertyValue<StickyStyle> {
        mixedValue(selectedObjects.filter { $0.type == "sticky" }.map { $0.stickyStyle ?? .classic })
    }

    public func setSelectedStickyStyle(_ style: StickyStyle) {
        modifySelectedObjects(matching: { $0.type == "sticky" }) { $0.stickyStyle = style }
    }

    public func setSelectedStickyColor(_ color: String) {
        setSelectedFillColor(color)
    }

    public func isStickyTextOverflowing(object: BoardObject) -> Bool {
        guard object.type == "sticky", let text = object.text, !text.isEmpty else { return false }
        return estimatedStickyTextHeight(object) > max(20, object.height - 28)
    }

    public func expandStickyToFit(id: String) {
        guard let index = objects.firstIndex(where: { $0.id == id }),
            objects[index].type == "sticky",
            let text = objects[index].text, !text.isEmpty
        else { return }
        let before = objects[index]
        let requiredHeight = ceil(estimatedStickyTextHeight(before) + 28 + 16)
        guard requiredHeight > before.height else { return }
        var updated = before
        updated.height = requiredHeight
        updated.updatedAt = ISO8601DateFormatter().string(from: Date())
        objects[index] = updated
        transactionManager.push(.modifyObjects(before: [before], after: [updated]))
        scheduleAutosave()
    }

    public var selectedGradientStart: String {
        selectedObjects.first?.fillGradientStart ?? selectedObjects.first?.fillColor ?? "#fde047"
    }
    public var selectedGradientEnd: String { selectedObjects.first?.fillGradientEnd ?? "#60a5fa" }
    public var selectedGradientEnabled: Bool {
        selectedObjects.contains { $0.fillGradientStart != nil && $0.fillGradientEnd != nil }
    }

    public func setSelectedStrokeColor(_ color: String) {
        modifySelectedObjects { $0.strokeColor = color }
    }

    /// 文字框右鍵的批次修改：混合選取不改圖片／圖形；富文字色與基底色
    /// 一起更新，否則 spans 的色彩會蓋過物件色。每次設定只有一筆歷史。
    public func setSelectedTextStyle(
        fontSize: Double? = nil, color: String? = nil, fontFamily: String? = nil,
        align: String? = nil, opacity: Double? = nil,
        bold: Bool? = nil, italic: Bool? = nil, underline: Bool? = nil
    ) {
        guard fontSize?.isFinite != false, opacity?.isFinite != false else { return }
        let pageIDs = Set(currentPageObjects.map(\.id))
        func update(_ object: inout BoardObject) {
            if let fontSize {
                object.fontSize = max(8, min(144, fontSize))
                if object.type == "text" { object.height = max(object.height, ceil(estimatedStickyTextHeight(object))) }
            }
            if let color { object.strokeColor = color }
            if let fontFamily, !fontFamily.isEmpty { object.fontFamily = fontFamily }
            if let align, ["left", "center", "right"].contains(align) { object.align = align }
            if let opacity { object.opacity = max(0.05, min(1, opacity)) }
            if let bold { object.isBold = bold }
            if let italic { object.isItalic = italic }
            if let underline { object.isUnderline = underline }
            object.richTextSpans = object.richTextSpans?.map { span in
                var changed = span
                if let color { changed.color = color }
                if let bold { changed.isBold = bold }
                if let italic { changed.isItalic = italic }
                if let underline { changed.isUnderline = underline }
                return changed
            }
        }
        modifySelectedObjects(matching: { object in
            guard pageIDs.contains(object.id), object.type == "text" || object.type == "sticky" else { return false }
            var changed = object
            update(&changed)
            return changed != object
        }, update)
    }

    public func setSelectedFillColor(_ color: String) {
        modifySelectedObjects { object in
            object.fillColor = color
            // 選單色會取消既有漸層，避免看起來未套用新填色。
            object.fillGradientStart = nil
            object.fillGradientEnd = nil
        }
    }

    public var selectedFillOpacity: PropertyValue<Double> {
        mixedValue(
            selectedObjects.filter {
                ["rect", "circle", "ellipse", "triangle", "quadrilateral", "diamond", "star", "sticky"]
                    .contains($0.type)
            }.map(\.fillOpacity))
    }

    public func setSelectedFillOpacity(_ opacity: Double) {
        modifySelectedObjects { object in object.fillOpacity = min(1, max(0, opacity)) }
    }

    /// 一次更新發布、一筆 undo 交易，避免逐個物件寫陣列導致重複刷新整張畫布。
    /// matching 是屬性適用範圍；所有呼叫都共用「跳過鎖定物件」規則。
    private func modifySelectedObjects(
        matching predicate: (BoardObject) -> Bool = { _ in true },
        _ update: (inout BoardObject) -> Void
    ) {
        let before = selectedObjects.filter { $0.isLocked != true && predicate($0) }
        guard !before.isEmpty else { return }
        let now = ISO8601DateFormatter().string(from: Date())
        let after = before.map { object in
            var changed = object
            update(&changed)
            changed.updatedAt = now
            return changed
        }
        let replacements = Dictionary(after.map { ($0.id, $0) }, uniquingKeysWith: { _, latest in latest })
        objects = objects.map { replacements[$0.id] ?? $0 }
        transactionManager.push(.modifyObjects(before: before, after: after))
        scheduleAutosave()
    }

    public func toggleSelectedGradient() {
        let selected = selectedObjects.filter { $0.isLocked != true }
        guard !selected.isEmpty else { return }
        let disable = selected.allSatisfy { $0.fillGradientStart != nil && $0.fillGradientEnd != nil }
        setSelectedGradientColors(
            start: disable ? nil : selectedGradientStart, end: disable ? nil : selectedGradientEnd)
    }

    public func setSelectedGradientColors(start: String?, end: String?) {
        modifySelectedObjects { object in
            object.fillGradientStart = start
            object.fillGradientEnd = end
            if let start, end != nil, object.fillColor == "none" { object.fillColor = start }
        }
    }

    public func setSelectedStrokeWidth(_ width: Double) {
        modifySelectedObjects { $0.strokeWidth = width }
    }

    public func setSelectedOpacity(_ opacity: Double) {
        modifySelectedObjects { $0.opacity = max(0.05, min(1.0, opacity)) }
    }

    public func setSelectedLineStyle(_ style: String) {
        modifySelectedObjects { $0.lineStyle = style }
    }

    public func setSelectedArrowHeadLength(_ value: Double) {
        modifySelectedArrows { $0.arrowHeadLength = value }
    }
    public func setSelectedArrowHeadWidth(_ value: Double) {
        modifySelectedArrows { $0.arrowHeadWidth = value }
    }

    private func modifySelectedArrows(_ update: (inout BoardObject) -> Void) {
        modifySelectedObjects(matching: { $0.type == "arrow" }, update)
    }

    public func setSelectedRotationAngle(_ degrees: Double) {
        modifySelectedObjects(matching: { !["line", "arrow"].contains($0.type) }) {
            $0.rotation = degrees.truncatingRemainder(dividingBy: 360.0)
        }
    }

    public func setSelectedLineExtension(_ extensionMode: LineExtension) {
        let matching = objects.filter {
            selectedIds.contains($0.id) && ($0.type == "line" || $0.type == "arrow") && $0.isLocked != true
        }
        guard matching.contains(where: { $0.extensionMode != extensionMode }) else {
            activeLineExtension = extensionMode
            return
        }
        let before = matching
        var after: [BoardObject] = []
        let now = ISO8601DateFormatter().string(from: Date())
        objects = objects.map { object in
            guard selectedIds.contains(object.id), object.type == "line" || object.type == "arrow",
                object.isLocked != true
            else { return object }
            var updated = object
            updated.extensionMode = extensionMode
            updated.updatedAt = now
            after.append(updated)
            return updated
        }
        activeLineExtension = extensionMode
        transactionManager.push(.modifyObjects(before: before, after: after))
        scheduleAutosave()
    }

    /// 混合值只需比較第一個值，無須替每一種屬性建立 Set。
    private func mixedValue<Value: Equatable>(_ values: [Value]) -> PropertyValue<Value> {
        guard let first = values.first else { return .none }
        return values.dropFirst().allSatisfy { $0 == first } ? .value(first) : .mixed
    }

    /// 核心不依賴 NSTextView。此處保留原字寬估算，兩個溢出入口共用同一規則。
    /// 字體實際排版仍由原生文字區決定；此值是便簽自動擴展的近似值。
    private func estimatedStickyTextHeight(_ object: BoardObject) -> Double {
        let availableWidth = max(20, object.width - 28)
        let fontSize = object.fontSize ?? 16
        var totalLines = 0
        for line in (object.text ?? "").components(separatedBy: "\n") {
            var width = 0.0
            var count = 1
            for character in line {
                let characterWidth = character.isASCII ? fontSize * 0.55 : fontSize * 1.05
                if width + characterWidth > availableWidth && width > 0 {
                    count += 1
                    width = characterWidth
                } else {
                    width += characterWidth
                }
            }
            totalLines += count
        }
        return Double(totalLines) * fontSize * 1.35
    }
}

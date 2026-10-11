import AppKit
import HeiBanCore
import SwiftUI

/// 普通畫布、透明畫布及文字草稿共用右鍵入口；AppKit 持有 popover，
/// 菜單結束後仍可輸入自訂值，不使用會被螢幕疊層蓋住的全域字體／色彩面板。
final class TextStyleContextMenu {
    private var popover: NSPopover?
    private static let colors = [
        ("#111827", "墨黑"), ("#ffffff", "白色"), ("#ef4444", "紅色"),
        ("#f59e0b", "橘色"), ("#22c55e", "綠色"), ("#3b82f6", "藍色"),
        ("#a855f7", "紫色"), ("#ec4899", "粉色")
    ]

    func append(to menu: NSMenu, engine: BoardEngine, draft: Bool = false, view: NSView, point: NSPoint) {
        let textObjects = engine.currentPageObjects.filter {
            engine.selectedIds.contains($0.id) && ($0.type == "text" || $0.type == "sticky") && $0.isLocked != true
        }
        guard draft || !textObjects.isEmpty else { return }
        menu.addItem(.separator())
        let title = NSMenuItem(title: draft ? "文字設定（目前草稿）" : "文字設定（\(textObjects.count) 個文字框）", action: nil, keyEquivalent: "")
        title.isEnabled = false
        menu.addItem(title)

        let sizeMenu = NSMenu()
        for size in [8, 12, 16, 18, 24, 32, 48, 64, 96, 144] {
            sizeMenu.addItem(TextMenuAction("\(size) pt") {
                if draft { engine.editingFontSize = Double(size) }
                else { engine.setSelectedTextStyle(fontSize: Double(size)) }
            })
        }
        let sizeItem = NSMenuItem(title: "文字大小", action: nil, keyEquivalent: "")
        sizeItem.submenu = sizeMenu
        menu.addItem(sizeItem)

        let colorMenu = NSMenu()
        for (hex, name) in Self.colors {
            colorMenu.addItem(TextMenuAction(name) {
                if draft {
                    engine.editingTextColor = hex
                    engine.requestInlineTextFormat("all:color:\(hex)")
                } else { engine.setSelectedTextStyle(color: hex) }
            })
        }
        let colorItem = NSMenuItem(title: "文字顏色", action: nil, keyEquivalent: "")
        colorItem.submenu = colorMenu
        menu.addItem(colorItem)
        for (title, action, enabled) in [
            ("粗體", "bold", textObjects.allSatisfy { $0.isBold == true }),
            ("斜體", "italic", textObjects.allSatisfy { $0.isItalic == true }),
            ("底線", "underline", textObjects.allSatisfy { $0.isUnderline == true })
        ] {
            let item = TextMenuAction(title) {
                if draft { engine.requestInlineTextFormat("all:\(action)") }
                else {
                    engine.setSelectedTextStyle(bold: action == "bold" ? !enabled : nil,
                        italic: action == "italic" ? !enabled : nil,
                        underline: action == "underline" ? !enabled : nil)
                }
            }
            if !draft { item.state = enabled ? .on : .off }
            menu.addItem(item)
        }
        menu.addItem(TextMenuAction("更多文字設定…") { [weak self, weak view] in
            guard let self, let view else { return }
            self.showSettings(engine: engine, draft: draft, view: view, point: point)
        })
        if !draft, textObjects.count == 1, let object = textObjects.first {
            menu.addItem(TextMenuAction("編輯文字內容") { engine.beginEditingText(object: object) })
        }
    }

    private func showSettings(engine: BoardEngine, draft: Bool, view: NSView, point: NSPoint) {
        popover?.close()
        let selection = engine.selectedIds
        let editingID = engine.editingTextObjectId
        let panel = NSPopover()
        panel.behavior = .transient
        panel.animates = false
        panel.contentViewController = NSHostingController(rootView: TextStyleSettings(
            engine: engine, draft: draft,
            apply: { [weak self] change in
                // 編輯對象換了就關閉，不能把延遲套用寫到另一份選取／草稿。
                guard draft ? engine.showInlineTextEditor && engine.editingTextObjectId == editingID
                    : engine.selectedIds == selection else { self?.close(); return }
                if draft {
                    if let size = change.size { engine.editingFontSize = size }
                    if let color = change.color {
                        engine.editingTextColor = color
                        engine.requestInlineTextFormat("all:color:\(color)")
                    }
                    if let family = change.family { engine.editingFontFamily = family }
                    if let align = change.align { engine.editingTextAlign = align }
                    if let opacity = change.opacity { engine.editingTextOpacity = opacity }
                } else {
                    engine.setSelectedTextStyle(fontSize: change.size, color: change.color,
                        fontFamily: change.family, align: change.align, opacity: change.opacity)
                }
                self?.close()
            }, close: { [weak self] in self?.close() }
        ))
        popover = panel
        panel.show(relativeTo: NSRect(origin: point, size: NSSize(width: 1, height: 1)), of: view, preferredEdge: .maxX)
        if let window = panel.contentViewController?.view.window, let parent = view.window {
            window.level = NSWindow.Level(rawValue: max(window.level.rawValue, parent.level.rawValue + 2))
        }
    }

    func close() { popover?.close(); popover = nil }
    deinit { popover?.close() }
}

/// 菜單持有 action item；由 item 自己接 action，避免 NSMenu 的弱 target
/// 在右鍵回呼結束後失效。
private final class TextMenuAction: NSMenuItem {
    private let perform: () -> Void
    init(_ title: String, perform: @escaping () -> Void) {
        self.perform = perform
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self
        action = #selector(invoke(_:))
    }
    required init(coder: NSCoder) { fatalError("init(coder:) unavailable") }
    @objc private func invoke(_ sender: Any?) { perform() }
}

private struct TextStyleChange {
    var size: Double?
    var color: String?
    var family: String?
    var align: String?
    var opacity: Double?
}

private struct TextStyleSettings: View {
    @ViewState private var size: Double
    @ViewState private var color: String
    @ViewState private var family: String
    @ViewState private var alignment: String
    @ViewState private var opacity: Double
    @ViewState private var changed = Set<String>()
    private let apply: (TextStyleChange) -> Void
    private let close: () -> Void
    private let mixed: Bool

    init(engine: BoardEngine, draft: Bool, apply: @escaping (TextStyleChange) -> Void, close: @escaping () -> Void) {
        let object = engine.selectedObjects.first { $0.type == "text" || $0.type == "sticky" }
        _size = ViewState(initialValue: draft ? engine.editingFontSize : object?.fontSize ?? 24)
        _color = ViewState(initialValue: draft ? engine.editingTextColor : object?.strokeColor ?? "#111827")
        _family = ViewState(initialValue: draft ? engine.editingFontFamily : object?.fontFamily ?? "PingFang TC")
        _alignment = ViewState(initialValue: draft ? engine.editingTextAlign : object?.align ?? "left")
        _opacity = ViewState(initialValue: draft ? engine.editingTextOpacity : object?.opacity ?? 1)
        self.apply = apply
        self.close = close
        mixed = !draft && engine.selectedObjects.filter { $0.type == "text" || $0.type == "sticky" }.count > 1
    }

    private var validColor: Bool { color.range(of: "^#[0-9a-fA-F]{6}$", options: .regularExpression) != nil }
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("文字設定").font(.headline)
            if mixed { Text("只套用你修改的欄位至所選文字框").font(.caption).foregroundStyle(.secondary) }
            HStack {
                Text("文字大小")
                TextField("pt", value: $size, format: .number).frame(width: 70)
                Stepper("pt", value: $size, in: 8...144)
            }
            HStack {
                Text("文字顏色")
                Circle().fill(Color(hex: color)).frame(width: 18, height: 18)
                TextField("#RRGGBB", text: $color).accessibilityLabel("自訂文字顏色十六進位值")
            }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
                ForEach(["#111827", "#ffffff", "#ef4444", "#f59e0b", "#22c55e", "#3b82f6", "#a855f7", "#ec4899"], id: \.self) { hex in
                    Button { color = hex; changed.insert("color") } label: {
                        Circle().fill(Color(hex: hex)).frame(width: 24, height: 24)
                            .overlay(Circle().stroke(.gray.opacity(0.5)))
                            .frame(width: 32, height: 32)
                    }.buttonStyle(.plain).accessibilityLabel("文字顏色 \(hex)")
                }
            }
            TextField("字體名稱", text: $family).accessibilityLabel("字體名稱")
            Picker("對齊", selection: $alignment) {
                Text("靠左").tag("left"); Text("置中").tag("center"); Text("靠右").tag("right")
            }.pickerStyle(.segmented)
            Text("不透明度 \(Int(opacity * 100))%")
            Slider(value: $opacity, in: 0.05...1).accessibilityLabel("文字不透明度")
            HStack {
                Button("取消", action: close)
                Spacer()
                Button("套用") {
                    apply(TextStyleChange(size: changed.contains("size") ? size : nil,
                        color: changed.contains("color") ? color : nil,
                        family: changed.contains("family") ? family : nil,
                        align: changed.contains("align") ? alignment : nil,
                        opacity: changed.contains("opacity") ? opacity : nil))
                }.buttonStyle(.borderedProminent)
                    .disabled(changed.isEmpty || !size.isFinite || !(8...144).contains(size) || !validColor)
            }
        }
        .font(.system(size: 12)).textFieldStyle(.roundedBorder)
        .padding(16).frame(width: 300).fixedSize(horizontal: true, vertical: true)
        .onChange(of: size) { _, _ in changed.insert("size") }
        .onChange(of: color) { _, _ in changed.insert("color") }
        .onChange(of: family) { _, _ in changed.insert("family") }
        .onChange(of: alignment) { _, _ in changed.insert("align") }
        .onChange(of: opacity) { _, _ in changed.insert("opacity") }
    }
}

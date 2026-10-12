import SwiftUI
import HeiBanCore

public struct CalculatorPanelView: View {
    @ObservedObject private var language = L10n.shared
    @ObservedObject var model: CalculatorModel
    @ObservedObject var engine: BoardEngine

    let workspaceSize: CGSize

    public init(model: CalculatorModel, engine: BoardEngine, workspaceSize: CGSize) {
        self.model = model
        self.engine = engine
        self.workspaceSize = workspaceSize
    }

    public var body: some View {
        if model.isVisible {
            FloatingToolPanel(title: "計算機", symbol: "plus.forwardslash.minus",
                              width: model.isScientificMode ? 320 : 250, workspaceSize: workspaceSize,
                              offset: $model.panelOffset, isCollapsed: $model.isCollapsed,
                              isVisible: $model.isVisible) {
                VStack(spacing: 0) {
                    displayArea
                    Divider().padding(.vertical, 4)
                    functionBar
                    keypadGrid
                    Divider().padding(.vertical, 6)
                    bottomActionBar
                }
            }
        }
    }

    // MARK: - Display Area
    private var displayArea: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if !model.expression.isEmpty {
                Text(model.expression)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Text(model.display)
                .font(.system(size: 26, weight: .semibold, design: .monospaced))
                .foregroundStyle(model.hasError ? Color.red : Color.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Function Bar
    private var functionBar: some View {
        HStack(spacing: 6) {
            Button {
                model.toggleDegreeMode()
            } label: {
                Text(model.isDegreeMode ? "DEG" : "RAD")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.accentColor.opacity(0.15), in: Capsule())
            }
            .buttonStyle(.plain)
            .help(L10n.t("切換角度 (DEG) / 弧度 (RAD) 模式"))

            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
                    model.isScientificMode.toggle()
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "function")
                    Text(model.isScientificMode ? "精簡" : "科學")
                }
                .font(.system(size: 10, weight: .medium))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.primary.opacity(0.06), in: Capsule())
            }
            .buttonStyle(.plain)

            Spacer()

            if !model.history.isEmpty {
                Menu {
                    ForEach(model.history) { item in
                        Button("\(item.expression) = \(item.result)") {
                            model.display = item.result
                        }
                    }
                } label: {
                    MenuDisclosureLabel(L10n.t("運算歷史記錄")) {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.system(size: 14)).foregroundStyle(.secondary)
                    }
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize(horizontal: true, vertical: true)
                .help(L10n.t("運算歷史記錄"))
            }
        }
        .padding(.bottom, 4)
    }

    // MARK: - Keypad Grid
    private var keypadGrid: some View {
        VStack(spacing: 5) {
            if model.isScientificMode {
                // Scientific Row 1: sin, cos, tan, log, ln
                HStack(spacing: 5) {
                    sciButton("sin") { model.sinFunction() }
                    sciButton("cos") { model.cosFunction() }
                    sciButton("tan") { model.tanFunction() }
                    sciButton("log") { model.log10Function() }
                    sciButton("ln") { model.lnFunction() }
                }

                // Scientific Row 2: √, x², 1/x, ^, (
                HStack(spacing: 5) {
                    sciButton("√") { model.squareRoot() }
                    sciButton("x²") { model.square() }
                    sciButton("1/x") { model.reciprocal() }
                    sciButton("^") { model.inputOperator("^") }
                    sciButton("±") { model.toggleSign() }
                }
            }

            // Standard Row 1: AC, C, %, ÷
            HStack(spacing: 5) {
                actionButton("AC", bg: .red.opacity(0.12), fg: .red) { model.clear() }
                actionButton("⌫", bg: .primary.opacity(0.06)) { model.backspace() }
                actionButton("%", bg: .primary.opacity(0.06)) { model.inputPercentage() }
                opButton("÷") { model.inputOperator("÷") }
            }

            // Standard Row 2: 7, 8, 9, ×
            HStack(spacing: 5) {
                numButton("7")
                numButton("8")
                numButton("9")
                opButton("×") { model.inputOperator("×") }
            }

            // Standard Row 3: 4, 5, 6, -
            HStack(spacing: 5) {
                numButton("4")
                numButton("5")
                numButton("6")
                opButton("-") { model.inputOperator("-") }
            }

            // Standard Row 4: 1, 2, 3, +
            HStack(spacing: 5) {
                numButton("1")
                numButton("2")
                numButton("3")
                opButton("+") { model.inputOperator("+") }
            }

            // Standard Row 5: 0, ., =
            HStack(spacing: 5) {
                numButton("0", span: 2)
                numButton(".") { model.inputDecimal() }
                actionButton("=", bg: Color.accentColor, fg: .white) { model.calculateResult() }
            }
        }
    }

    // MARK: - Bottom Action Bar
    private var bottomActionBar: some View {
        HStack(spacing: 8) {
            Button {
                model.copyResult()
                engine.showTemporaryStatus("已拷貝運算結果")
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "doc.on.doc")
                    Text(L10n.t("拷貝"))
                }
                .font(.system(size: 11, weight: .medium))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help(L10n.t("拷貝運算數值至剪貼簿"))

            Spacer()

            Button {
                model.insertResultToBoard(engine: engine, asExpression: false)
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "text.insert")
                    Text(L10n.t("插入畫布"))
                }
                .font(.system(size: 11, weight: .semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.18), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Color.accentColor)
            }
            .buttonStyle(.plain)
            .help(L10n.t("將運算結果插入黑板為可編輯文字物件"))
        }
    }

    // MARK: - Keypad Button Builders

    private func numButton(_ label: String, span: Int = 1, action: (() -> Void)? = nil) -> some View {
        Button {
            if let action = action { action() } else { model.inputDigit(label) }
        } label: {
            Text(label)
                .font(.system(size: 15, weight: .medium, design: .monospaced))
                .frame(maxWidth: span == 2 ? .infinity : nil)
                .frame(height: 30)
                .frame(minWidth: 32)
                .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private func opButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 16, weight: .bold))
                .frame(height: 30)
                .frame(minWidth: 36)
                .background(Color.orange.opacity(0.16), in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(Color.orange)
        }
        .buttonStyle(.plain)
    }

    private func sciButton(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .frame(maxWidth: .infinity)
                .frame(height: 24)
                .background(Color.primary.opacity(0.04), in: RoundedRectangle(cornerRadius: 5))
        }
        .buttonStyle(.plain)
    }

    private func actionButton(_ label: String, bg: Color, fg: Color = .primary, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 14, weight: .semibold))
                .frame(height: 30)
                .frame(minWidth: 36)
                .frame(maxWidth: .infinity)
                .background(bg, in: RoundedRectangle(cornerRadius: 6))
                .foregroundStyle(fg)
        }
        .buttonStyle(.plain)
    }
}

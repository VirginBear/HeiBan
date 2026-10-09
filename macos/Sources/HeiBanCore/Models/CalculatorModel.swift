import Foundation
import AppKit

public struct CalculatorHistoryItem: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    public let expression: String
    public let result: String
    public let timestamp: String

    public init(id: String = UUID().uuidString, expression: String, result: String, timestamp: String = ISO8601DateFormatter().string(from: Date())) {
        self.id = id
        self.expression = expression
        self.result = result
        self.timestamp = timestamp
    }
}

public final class CalculatorModel: ObservableObject {
    @Published public var display: String = "0"
    @Published public var expression: String = ""
    @Published public var history: [CalculatorHistoryItem] = []
    @Published public var isDegreeMode: Bool = true
    @Published public var isScientificMode: Bool = false
    @Published public var hasError: Bool = false
    @Published public var isVisible: Bool = false
    @Published public var isCollapsed: Bool = false
    @Published public var panelOffset: CGSize = CGSize(width: 80, height: 80)

    private var currentInput: String = "0"
    private var pendingOperator: String? = nil
    private var previousOperand: Double? = nil
    private var isEnteringNewNumber: Bool = true
    private var openParenCount: Int = 0

    public init() {}

    // MARK: - Input Actions

    public func inputDigit(_ digit: String) {
        guard !hasError else {
            clear()
            inputDigit(digit)
            return
        }

        if isEnteringNewNumber {
            currentInput = digit
            isEnteringNewNumber = false
        } else {
            if currentInput == "0" {
                currentInput = digit
            } else {
                currentInput += digit
            }
        }
        display = currentInput
    }

    public func inputDecimal() {
        guard !hasError else {
            clear()
            inputDecimal()
            return
        }

        if isEnteringNewNumber {
            currentInput = "0."
            isEnteringNewNumber = false
        } else if !currentInput.contains(".") {
            currentInput += "."
        }
        display = currentInput
    }

    public func inputOperator(_ op: String) {
        guard !hasError else { return }

        let normalizedOp: String
        switch op {
        case "+", "＋": normalizedOp = "+"
        case "-", "−", "–": normalizedOp = "-"
        case "*", "×", "x", "X": normalizedOp = "×"
        case "/", "÷": normalizedOp = "÷"
        case "^": normalizedOp = "^"
        default: normalizedOp = op
        }

        let currentValue = parseDisplayValue()

        if let prev = previousOperand, let pending = pendingOperator, !isEnteringNewNumber {
            // Chain calculation
            let result = executeBinaryOp(left: prev, right: currentValue, op: pending)
            if let result = result {
                previousOperand = result
                display = formatNumber(result)
            } else {
                showError()
                return
            }
        } else {
            previousOperand = currentValue
        }

        pendingOperator = normalizedOp
        expression = "\(formatNumber(previousOperand!)) \(normalizedOp)"
        isEnteringNewNumber = true
    }

    public func inputPercentage() {
        guard !hasError else { return }
        let current = parseDisplayValue()

        if let prev = previousOperand, let op = pendingOperator {
            let percentValue: Double
            switch op {
            case "+", "-":
                // 200 + 10% = 220 (200 + 200 * 0.1)
                percentValue = prev * (current / 100.0)
            case "×":
                // 200 × 10% = 20 (200 * 0.1)
                percentValue = current / 100.0
            case "÷":
                // 200 ÷ 10% = 2000 (200 / 0.1)
                percentValue = current / 100.0
            default:
                percentValue = current / 100.0
            }
            currentInput = formatNumber(percentValue)
            display = currentInput
        } else {
            let result = current / 100.0
            currentInput = formatNumber(result)
            display = currentInput
        }
    }

    public func calculateResult() {
        guard !hasError else { return }
        guard let prev = previousOperand, let op = pendingOperator else { return }

        let current = parseDisplayValue()
        let fullExpr = "\(formatNumber(prev)) \(op) \(formatNumber(current))"

        guard let result = executeBinaryOp(left: prev, right: current, op: op) else {
            showError()
            return
        }

        let formattedResult = formatNumber(result)
        display = formattedResult
        expression = "\(fullExpr) ="
        history.insert(CalculatorHistoryItem(expression: fullExpr, result: formattedResult), at: 0)
        if history.count > 30 { history.removeLast() }

        previousOperand = result
        pendingOperator = nil
        isEnteringNewNumber = true
    }

    public func toggleSign() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        let negated = -val
        currentInput = formatNumber(negated)
        display = currentInput
    }

    public func clear() {
        display = "0"
        expression = ""
        currentInput = "0"
        pendingOperator = nil
        previousOperand = nil
        isEnteringNewNumber = true
        hasError = false
        openParenCount = 0
    }

    public func clearEntry() {
        if hasError {
            clear()
            return
        }
        currentInput = "0"
        display = "0"
        isEnteringNewNumber = true
    }

    public func backspace() {
        guard !hasError, !isEnteringNewNumber else { return }
        if currentInput.count > 1 {
            currentInput.removeLast()
            if currentInput == "-" { currentInput = "0"; isEnteringNewNumber = true }
        } else {
            currentInput = "0"
            isEnteringNewNumber = true
        }
        display = currentInput
    }

    // MARK: - Scientific Functions

    public func squareRoot() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        guard val >= 0 else {
            showError()
            return
        }
        let res = sqrt(val)
        recordUnary(funcName: "√", operand: val, result: res)
    }

    public func square() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        let res = val * val
        recordUnary(funcName: "sqr", operand: val, result: res)
    }

    public func reciprocal() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        guard val != 0 else {
            showError()
            return
        }
        let res = 1.0 / val
        recordUnary(funcName: "1/", operand: val, result: res)
    }

    public func sinFunction() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        let radians = isDegreeMode ? (val * Double.pi / 180.0) : val
        // Round very small values near 0
        var res = sin(radians)
        if abs(res) < 1e-15 { res = 0.0 }
        recordUnary(funcName: "sin", operand: val, result: res)
    }

    public func cosFunction() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        let radians = isDegreeMode ? (val * Double.pi / 180.0) : val
        var res = cos(radians)
        if abs(res) < 1e-15 { res = 0.0 }
        recordUnary(funcName: "cos", operand: val, result: res)
    }

    public func tanFunction() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        let radians = isDegreeMode ? (val * Double.pi / 180.0) : val
        let c = cos(radians)
        guard abs(c) > 1e-15 else {
            showError()
            return
        }
        var res = tan(radians)
        if abs(res) < 1e-15 { res = 0.0 }
        recordUnary(funcName: "tan", operand: val, result: res)
    }

    public func log10Function() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        guard val > 0 else {
            showError()
            return
        }
        let res = log10(val)
        recordUnary(funcName: "log", operand: val, result: res)
    }

    public func lnFunction() {
        guard !hasError else { return }
        let val = parseDisplayValue()
        guard val > 0 else {
            showError()
            return
        }
        let res = log(val)
        recordUnary(funcName: "ln", operand: val, result: res)
    }

    public func toggleDegreeMode() {
        isDegreeMode.toggle()
    }

    // MARK: - Direct Expression Evaluation (Parentheses & Full expressions)

    public func evaluateExpressionString(_ inputExpr: String) -> Double? {
        let clean = inputExpr
            .replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "＋", with: "+")
            .replacingOccurrences(of: "−", with: "-")
            .replacingOccurrences(of: " ", with: "")
        guard !clean.isEmpty else { return nil }

        let exp = NSExpression(format: clean)
        if let val = exp.expressionValue(with: nil, context: nil) as? NSNumber {
            return val.doubleValue
        }
        return nil
    }

    // MARK: - Integration with Board Canvas

    @discardableResult
    public func insertResultToBoard(engine: BoardEngine, asExpression: Bool = false) -> BoardObject {
        let insertText = asExpression && !expression.isEmpty ? "\(expression) \(display)" : display

        // Center on the current viewport
        let centerScreen = Point(x: Double(engine.canvasSize.width / 2.0), y: Double(engine.canvasSize.height / 2.0))
        let centerWorld = VectorMath.screenToWorld(centerScreen, viewport: engine.viewport)

        let obj = BoardObject(
            type: "text",
            x: centerWorld.x - 60.0,
            y: centerWorld.y - 20.0,
            width: 140.0,
            height: 44.0,
            strokeColor: engine.activeColor,
            fillColor: "none",
            strokeWidth: 2.0,
            text: insertText,
            fontSize: 22.0,
            fontFamily: "Menlo",
            isBold: true,
            pageId: engine.activePageId
        )

        engine.addObject(obj)
        engine.selectedIds = [obj.id]
        engine.showTemporaryStatus("已插入運算結果至畫布")
        return obj
    }

    public func copyResult() {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(display, forType: .string)
    }

    // MARK: - Helpers

    private func parseDisplayValue() -> Double {
        if let d = Double(currentInput) { return d }
        return 0.0
    }

    private func executeBinaryOp(left: Double, right: Double, op: String) -> Double? {
        switch op {
        case "+":
            return left + right
        case "-":
            return left - right
        case "×":
            return left * right
        case "÷":
            guard abs(right) > 1e-15 else { return nil }
            return left / right
        case "^":
            return pow(left, right)
        default:
            return nil
        }
    }

    private func recordUnary(funcName: String, operand: Double, result: Double) {
        let formattedRes = formatNumber(result)
        let exprStr = "\(funcName)(\(formatNumber(operand)))"
        display = formattedRes
        currentInput = formattedRes
        expression = "\(exprStr) ="
        history.insert(CalculatorHistoryItem(expression: exprStr, result: formattedRes), at: 0)
        if history.count > 30 { history.removeLast() }
        isEnteringNewNumber = true
    }

    private func showError() {
        hasError = true
        display = "錯誤"
        expression = ""
    }

    public func formatNumber(_ val: Double) -> String {
        guard !val.isNaN && !val.isInfinite else { return "錯誤" }

        // Precision cleanup to avoid 0.30000000000000004
        let rounded = (val * 1e10).rounded() / 1e10
        if rounded.truncatingRemainder(dividingBy: 1.0) == 0 {
            if abs(rounded) < 1e14 {
                return String(format: "%.0f", rounded)
            }
        }

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 10
        formatter.usesGroupingSeparator = false
        if let str = formatter.string(from: NSNumber(value: rounded)) {
            return str
        }
        return "\(rounded)"
    }
}

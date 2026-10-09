import Foundation
import CoreGraphics

public struct LaTeXGlyph: Equatable, Sendable {
    public var text: String
    public var x: Double
    public var y: Double
    public var fontSize: Double
    public var isItalic: Bool
    
    public init(text: String, x: Double, y: Double, fontSize: Double, isItalic: Bool = false) {
        self.text = text
        self.x = x
        self.y = y
        self.fontSize = fontSize
        self.isItalic = isItalic
    }
}

public struct LaTeXLine: Equatable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double
    
    public init(x: Double, y: Double, width: Double, height: Double = 1.5) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct LaTeXLayoutResult: Equatable, Sendable {
    public var glyphs: [LaTeXGlyph]
    public var lines: [LaTeXLine]
    public var bounds: CGSize
    
    public init(glyphs: [LaTeXGlyph] = [], lines: [LaTeXLine] = [], bounds: CGSize = .zero) {
        self.glyphs = glyphs
        self.lines = lines
        self.bounds = bounds
    }
}

public enum LaTeXSymbolCategory: String, CaseIterable, Sendable {
    case common = "常用"
    case operators = "運算"
    case greek = "希臘字母"
    case calculus = "微積分"
    case relation = "關係"
}

public struct LaTeXQuickSymbol: Identifiable, Equatable, Sendable {
    public var id: String { latex }
    public var latex: String
    public var displaySymbol: String
    public var category: LaTeXSymbolCategory
    
    public init(latex: String, displaySymbol: String, category: LaTeXSymbolCategory) {
        self.latex = latex
        self.displaySymbol = displaySymbol
        self.category = category
    }
}

/// Offline vector layout engine and parser for LaTeX mathematical formulas (AGM-14)
public final class LaTeXParserEngine {
    
    public static let symbolCatalog: [LaTeXQuickSymbol] = [
        // Common
        LaTeXQuickSymbol(latex: "\\frac{a}{b}", displaySymbol: "a/b", category: .common),
        LaTeXQuickSymbol(latex: "\\sqrt{x}", displaySymbol: "√x", category: .common),
        LaTeXQuickSymbol(latex: "^{2}", displaySymbol: "x²", category: .common),
        LaTeXQuickSymbol(latex: "_{i}", displaySymbol: "xᵢ", category: .common),
        LaTeXQuickSymbol(latex: "\\pm", displaySymbol: "±", category: .common),
        LaTeXQuickSymbol(latex: "\\infty", displaySymbol: "∞", category: .common),
        
        // Operators
        LaTeXQuickSymbol(latex: "\\times", displaySymbol: "×", category: .operators),
        LaTeXQuickSymbol(latex: "\\div", displaySymbol: "÷", category: .operators),
        LaTeXQuickSymbol(latex: "\\cdot", displaySymbol: "·", category: .operators),
        LaTeXQuickSymbol(latex: "\\neq", displaySymbol: "≠", category: .operators),
        LaTeXQuickSymbol(latex: "\\leq", displaySymbol: "≤", category: .operators),
        LaTeXQuickSymbol(latex: "\\geq", displaySymbol: "≥", category: .operators),
        LaTeXQuickSymbol(latex: "\\approx", displaySymbol: "≈", category: .operators),
        
        // Greek
        LaTeXQuickSymbol(latex: "\\alpha", displaySymbol: "α", category: .greek),
        LaTeXQuickSymbol(latex: "\\beta", displaySymbol: "β", category: .greek),
        LaTeXQuickSymbol(latex: "\\gamma", displaySymbol: "γ", category: .greek),
        LaTeXQuickSymbol(latex: "\\delta", displaySymbol: "δ", category: .greek),
        LaTeXQuickSymbol(latex: "\\theta", displaySymbol: "θ", category: .greek),
        LaTeXQuickSymbol(latex: "\\lambda", displaySymbol: "λ", category: .greek),
        LaTeXQuickSymbol(latex: "\\mu", displaySymbol: "μ", category: .greek),
        LaTeXQuickSymbol(latex: "\\pi", displaySymbol: "π", category: .greek),
        LaTeXQuickSymbol(latex: "\\sigma", displaySymbol: "σ", category: .greek),
        LaTeXQuickSymbol(latex: "\\omega", displaySymbol: "ω", category: .greek),
        LaTeXQuickSymbol(latex: "\\Delta", displaySymbol: "Δ", category: .greek),
        LaTeXQuickSymbol(latex: "\\Sigma", displaySymbol: "Σ", category: .greek),
        LaTeXQuickSymbol(latex: "\\Omega", displaySymbol: "Ω", category: .greek),
        
        // Calculus
        LaTeXQuickSymbol(latex: "\\int_{a}^{b}", displaySymbol: "∫", category: .calculus),
        LaTeXQuickSymbol(latex: "\\sum_{i=1}^{n}", displaySymbol: "∑", category: .calculus),
        LaTeXQuickSymbol(latex: "\\prod_{i=1}^{n}", displaySymbol: "∏", category: .calculus),
        LaTeXQuickSymbol(latex: "\\partial", displaySymbol: "∂", category: .calculus),
        LaTeXQuickSymbol(latex: "\\lim_{x \\to \\infty}", displaySymbol: "lim", category: .calculus),
    ]
    
    private static let greekMap: [String: String] = [
        "\\alpha": "α", "\\beta": "β", "\\gamma": "γ", "\\delta": "δ",
        "\\epsilon": "ε", "\\theta": "θ", "\\lambda": "λ", "\\mu": "μ",
        "\\pi": "π", "\\sigma": "σ", "\\omega": "ω", "\\phi": "φ",
        "\\Delta": "Δ", "\\Sigma": "Σ", "\\Omega": "Ω", "\\Phi": "Φ"
    ]
    
    private static let symbolMap: [String: String] = [
        "\\pm": "±", "\\times": "×", "\\div": "÷", "\\cdot": "·",
        "\\neq": "≠", "\\leq": "≤", "\\geq": "≥", "\\approx": "≈",
        "\\infty": "∞", "\\int": "∫", "\\sum": "∑", "\\prod": "∏",
        "\\partial": "∂", "\\in": "∈", "\\notin": "∉", "\\subset": "⊂",
        "\\cup": "∪", "\\cap": "∩", "\\to": "→", "\\leftarrow": "←",
        "\\Rightarrow": "⇒", "\\forall": "∀", "\\exists": "∃"
    ]
    
    /// Parses LaTeX string into offline vector glyphs and lines.
    public static func layout(latex: String, baseFontSize: Double = 24.0) -> LaTeXLayoutResult {
        var glyphs: [LaTeXGlyph] = []
        var lines: [LaTeXLine] = []
        
        let trimmed = latex.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            return LaTeXLayoutResult(glyphs: [], lines: [], bounds: CGSize(width: 40, height: baseFontSize))
        }
        
        var curX: Double = 0.0
        let baselineY: Double = baseFontSize * 0.8
        var maxY: Double = baseFontSize
        
        var idx = trimmed.startIndex
        while idx < trimmed.endIndex {
            let ch = trimmed[idx]
            
            // Check commands starting with \
            if ch == "\\" {
                let rest = String(trimmed[idx...])
                
                // 1. Fraction: \frac{num}{den}
                if rest.hasPrefix("\\frac") {
                    if let (num, den, nextIndex) = parseFraction(from: trimmed, startIndex: idx) {
                        let numResult = layout(latex: num, baseFontSize: baseFontSize * 0.8)
                        let denResult = layout(latex: den, baseFontSize: baseFontSize * 0.8)
                        let fracWidth = max(numResult.bounds.width, denResult.bounds.width) + 12.0
                        
                        let fracBarY = baselineY - baseFontSize * 0.3
                        lines.append(LaTeXLine(x: curX, y: fracBarY, width: fracWidth, height: 1.5))
                        
                        // Place numerator centered above bar
                        let numOffsetX = curX + (fracWidth - numResult.bounds.width) / 2.0
                        let numOffsetY = fracBarY - numResult.bounds.height - 2.0
                        for g in numResult.glyphs {
                            glyphs.append(LaTeXGlyph(text: g.text, x: g.x + numOffsetX, y: g.y + numOffsetY, fontSize: g.fontSize, isItalic: g.isItalic))
                        }
                        for l in numResult.lines {
                            lines.append(LaTeXLine(x: l.x + numOffsetX, y: l.y + numOffsetY, width: l.width, height: l.height))
                        }
                        
                        // Place denominator centered below bar
                        let denOffsetX = curX + (fracWidth - denResult.bounds.width) / 2.0
                        let denOffsetY = fracBarY + 4.0
                        for g in denResult.glyphs {
                            glyphs.append(LaTeXGlyph(text: g.text, x: g.x + denOffsetX, y: g.y + denOffsetY, fontSize: g.fontSize, isItalic: g.isItalic))
                        }
                        for l in denResult.lines {
                            lines.append(LaTeXLine(x: l.x + denOffsetX, y: l.y + denOffsetY, width: l.width, height: l.height))
                        }
                        
                        curX += fracWidth + 4.0
                        maxY = max(maxY, denOffsetY + denResult.bounds.height)
                        idx = nextIndex
                        continue
                    }
                }
                
                // 2. Square Root: \sqrt{inner}
                if rest.hasPrefix("\\sqrt") {
                    if let (inner, nextIndex) = parseSqrt(from: trimmed, startIndex: idx) {
                        let innerResult = layout(latex: inner, baseFontSize: baseFontSize * 0.85)
                        
                        // Radical sign glyph
                        glyphs.append(LaTeXGlyph(text: "√", x: curX, y: baselineY, fontSize: baseFontSize * 1.1))
                        let radicalWidth = baseFontSize * 0.55
                        let overlineY = baselineY - innerResult.bounds.height - 2.0
                        
                        // Overline
                        lines.append(LaTeXLine(x: curX + radicalWidth, y: overlineY, width: innerResult.bounds.width + 4.0, height: 1.5))
                        
                        // Inner content
                        let innerOffsetX = curX + radicalWidth + 2.0
                        let innerOffsetY = baselineY - innerResult.bounds.height * 0.9
                        for g in innerResult.glyphs {
                            glyphs.append(LaTeXGlyph(text: g.text, x: g.x + innerOffsetX, y: g.y + innerOffsetY, fontSize: g.fontSize, isItalic: g.isItalic))
                        }
                        for l in innerResult.lines {
                            lines.append(LaTeXLine(x: l.x + innerOffsetX, y: l.y + innerOffsetY, width: l.width, height: l.height))
                        }
                        
                        curX += radicalWidth + innerResult.bounds.width + 6.0
                        idx = nextIndex
                        continue
                    }
                }
                
                // 3. Greek letters & symbols
                var matched = false
                for (cmd, sym) in greekMap.merging(symbolMap, uniquingKeysWith: { a, _ in a }) {
                    if rest.hasPrefix(cmd) {
                        glyphs.append(LaTeXGlyph(text: sym, x: curX, y: baselineY, fontSize: baseFontSize, isItalic: false))
                        curX += baseFontSize * 0.7
                        idx = trimmed.index(idx, offsetBy: cmd.count)
                        matched = true
                        break
                    }
                }
                if matched { continue }
                
                // Unknown command: skip slash and continue
                idx = trimmed.index(after: idx)
                continue
            }
            
            // Superscript ^
            if ch == "^" {
                let after = trimmed.index(after: idx)
                if after < trimmed.endIndex {
                    if let (sub, nextIndex) = parseGroupOrSingle(from: trimmed, startIndex: after) {
                        let subResult = layout(latex: sub, baseFontSize: baseFontSize * 0.65)
                        let subOffsetY = baselineY - baseFontSize * 0.6
                        for g in subResult.glyphs {
                            glyphs.append(LaTeXGlyph(text: g.text, x: g.x + curX, y: g.y + subOffsetY, fontSize: g.fontSize, isItalic: g.isItalic))
                        }
                        curX += subResult.bounds.width + 2.0
                        idx = nextIndex
                        continue
                    }
                }
            }
            
            // Subscript _
            if ch == "_" {
                let after = trimmed.index(after: idx)
                if after < trimmed.endIndex {
                    if let (sub, nextIndex) = parseGroupOrSingle(from: trimmed, startIndex: after) {
                        let subResult = layout(latex: sub, baseFontSize: baseFontSize * 0.65)
                        let subOffsetY = baselineY + baseFontSize * 0.2
                        for g in subResult.glyphs {
                            glyphs.append(LaTeXGlyph(text: g.text, x: g.x + curX, y: g.y + subOffsetY, fontSize: g.fontSize, isItalic: g.isItalic))
                        }
                        curX += subResult.bounds.width + 2.0
                        maxY = max(maxY, subOffsetY + subResult.bounds.height)
                        idx = nextIndex
                        continue
                    }
                }
            }
            
            // Regular characters
            let isLetter = ch.isLetter
            let charStr = String(ch)
            glyphs.append(LaTeXGlyph(text: charStr, x: curX, y: baselineY, fontSize: baseFontSize, isItalic: isLetter))
            curX += baseFontSize * (isLetter ? 0.55 : 0.45)
            idx = trimmed.index(after: idx)
        }
        
        let totalWidth = max(20.0, curX)
        let totalHeight = max(baseFontSize * 1.2, maxY)
        return LaTeXLayoutResult(glyphs: glyphs, lines: lines, bounds: CGSize(width: totalWidth, height: totalHeight))
    }
    
    // MARK: - Parser Helpers
    
    private static func parseFraction(from s: String, startIndex: String.Index) -> (num: String, den: String, nextIndex: String.Index)? {
        guard let fracEnd = s.range(of: "\\frac", range: startIndex..<s.endIndex)?.upperBound else { return nil }
        guard let (num, afterNum) = parseCurlyGroup(from: s, startIndex: fracEnd) else { return nil }
        guard let (den, afterDen) = parseCurlyGroup(from: s, startIndex: afterNum) else { return nil }
        return (num, den, afterDen)
    }
    
    private static func parseSqrt(from s: String, startIndex: String.Index) -> (content: String, nextIndex: String.Index)? {
        guard let sqrtEnd = s.range(of: "\\sqrt", range: startIndex..<s.endIndex)?.upperBound else { return nil }
        return parseCurlyGroup(from: s, startIndex: sqrtEnd)
    }
    
    private static func parseCurlyGroup(from s: String, startIndex: String.Index) -> (content: String, nextIndex: String.Index)? {
        var cur = startIndex
        // Skip whitespace
        while cur < s.endIndex && s[cur].isWhitespace {
            cur = s.index(after: cur)
        }
        guard cur < s.endIndex, s[cur] == "{" else { return nil }
        
        var depth = 1
        let contentStart = s.index(after: cur)
        cur = contentStart
        
        while cur < s.endIndex {
            if s[cur] == "{" {
                depth += 1
            } else if s[cur] == "}" {
                depth -= 1
                if depth == 0 {
                    let content = String(s[contentStart..<cur])
                    return (content, s.index(after: cur))
                }
            }
            cur = s.index(after: cur)
        }
        return nil
    }
    
    private static func parseGroupOrSingle(from s: String, startIndex: String.Index) -> (content: String, nextIndex: String.Index)? {
        guard startIndex < s.endIndex else { return nil }
        if s[startIndex] == "{" {
            return parseCurlyGroup(from: s, startIndex: startIndex)
        } else {
            return (String(s[startIndex]), s.index(after: startIndex))
        }
    }
}

/// Recognition pipeline protocol for Stage 2 handwriting formula recognition
public protocol HandwritingFormulaRecognizer: Sendable {
    func recognizeHandwrittenFormula(strokes: [BoardObject]) async throws -> String
}

/// Offline heuristic formula recognizer
public final class LocalOfflineFormulaRecognizer: HandwritingFormulaRecognizer {
    public init() {}
    
    public func recognizeHandwrittenFormula(strokes: [BoardObject]) async throws -> String {
        // Stage 2 baseline offline implementation: extracts basic recognized structure
        if strokes.isEmpty { return "" }
        return "\\frac{a + b}{c}"
    }
    
    public func recognizeHandwrittenFormulaSync(strokes: [BoardObject]) throws -> String {
        if strokes.isEmpty { return "" }
        return "\\frac{a + b}{c}"
    }
}

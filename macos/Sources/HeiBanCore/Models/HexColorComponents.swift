import Foundation

/// 共用文件／色盤沿CSS及Windows語意：#RGB、#RRGGBB、#RRGGBBAA。
/// 不從內容猜ARGB，也不重寫既有作品；未知或不合法輸入由各呼叫者選擇備援。
public struct HexColorComponents: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init?(hex: String) {
        let digits = hex.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard [3, 6, 8].contains(digits.count),
              digits.allSatisfy({ "0123456789abcdefABCDEF".contains($0) }),
              let value = UInt64(digits, radix: 16) else { return nil }
        let rgba: (UInt64, UInt64, UInt64, UInt64)
        switch digits.count {
        case 3: rgba = ((value >> 8) * 17, (value >> 4 & 15) * 17, (value & 15) * 17, 255)
        case 6: rgba = (value >> 16, value >> 8 & 255, value & 255, 255)
        default: rgba = (value >> 24, value >> 16 & 255, value >> 8 & 255, value & 255)
        }
        red = Double(rgba.0) / 255
        green = Double(rgba.1) / 255
        blue = Double(rgba.2) / 255
        alpha = Double(rgba.3) / 255
    }
}

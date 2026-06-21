import Foundation

/// 解析十六进制颜色字符串为 0...1 的 RGBA 分量。
/// 支持 `#RGB` / `#RRGGBB` / `#RRGGBBAA`,带或不带前导 `#`;非法输入返回 nil。
public func rgbaComponents(hex: String) -> (red: Double, green: Double, blue: Double, alpha: Double)? {
    var s = hex.trimmingCharacters(in: .whitespacesAndNewlines)
    if s.hasPrefix("#") { s.removeFirst() }
    guard let value = UInt64(s, radix: 16) else { return nil }
    switch s.count {
    case 3:
        let r = Double((value >> 8) & 0xF) / 15.0
        let g = Double((value >> 4) & 0xF) / 15.0
        let b = Double(value & 0xF) / 15.0
        return (r, g, b, 1.0)
    case 6:
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return (r, g, b, 1.0)
    case 8:
        let r = Double((value >> 24) & 0xFF) / 255.0
        let g = Double((value >> 16) & 0xFF) / 255.0
        let b = Double((value >> 8) & 0xFF) / 255.0
        let a = Double(value & 0xFF) / 255.0
        return (r, g, b, a)
    default:
        return nil
    }
}

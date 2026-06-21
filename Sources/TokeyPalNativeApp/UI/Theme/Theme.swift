import SwiftUI
import TokeyPalNative

extension Color {
    /// 用 TokeyPalNative 的十六进制解析构造 sRGB 颜色;非法字符串回退黑色。
    init(hex: String) {
        let c = rgbaComponents(hex: hex) ?? (red: 0, green: 0, blue: 0, alpha: 1)
        self = Color(.sRGB, red: c.red, green: c.green, blue: c.blue, opacity: c.alpha)
    }
}

/// 颜色 token,取自 styles.css 的 website skin(.dashboard-shell)。
enum ThemeColor {
    static let background = Color(hex: "#fef6ec")
    static let surface = Color(hex: "#ffffff")
    static let surfaceLowest = Color(hex: "#fffdf8")
    static let surfaceLow = Color(hex: "#fff4e0")
    static let surfaceHigh = Color(hex: "#efe4d2")
    static let onSurface = Color(hex: "#17120d")
    static let onMuted = Color(hex: "#675f55")
    static let primaryStrong = Color(hex: "#ef5a50")
    static let secondary = Color(hex: "#3bc9a0")
    static let cyan = Color(hex: "#48b9d8")
    static let gold = Color(hex: "#f3b23f")
    static let error = Color(hex: "#c34a35")
    /// rgba(89,59,33,0.16)
    static let outlineSoft = Color(.sRGB, red: 89.0 / 255.0, green: 59.0 / 255.0, blue: 33.0 / 255.0, opacity: 0.16)
}

/// 尺寸 / 圆角 token。
enum ThemeMetric {
    static let windowWidth: CGFloat = 1120
    static let windowHeight: CGFloat = 748
    static let sidebarWidth: CGFloat = 200
    static let headerHeight: CGFloat = 100
    static let windowCornerRadius: CGFloat = 28
    static let panelCornerRadius: CGFloat = 22
    static let navCornerRadius: CGFloat = 16
    static let buttonCornerRadius: CGFloat = 8
}

/// 字体 token,统一系统 SF Pro(不为贴近 Inter 微调)。
enum ThemeFont {
    static let eyebrow = Font.system(size: 11, weight: .black)
    static let largeTitle = Font.system(size: 42, weight: .black)
    static let panelHeading = Font.system(size: 11, weight: .black)
    static let statValue = Font.system(size: 31, weight: .black)
    static let body = Font.system(size: 14)
}
